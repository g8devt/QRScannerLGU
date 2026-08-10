"""
PayMongo Checkout Session integration.

Env:
    PAYMONGO_SECRET_KEY  - PayMongo secret key (sk_live_... or sk_test_...)

Dispatcher endpoints exposed from this module:
    create_paymongo_checkout
    check_paymongo_status

Basic Auth per PayMongo docs:
    Authorization: Basic base64(SECRET_KEY + ':')
Amounts are in centavos (1 PHP = 100 centavos). Minimum 2000.
"""
import base64
import json
import logging
import os
import urllib.error
import urllib.request
from datetime import datetime

from helpers.auth import ok, fail, require

logger = logging.getLogger()

_PAYMONGO_BASE = 'https://api.paymongo.com/v1'

# Default success/cancel callback roots. These can be overridden per-call by
# the Flutter client if needed; WebView detection is URL-substring based so
# any absolute URL containing `/success` or `/cancel` will be recognised.
_DEFAULT_SUCCESS_URL = 'https://paymongo.example/success'
_DEFAULT_CANCEL_URL = 'https://paymongo.example/cancel'


def _auth_header():
    secret = os.environ.get('PAYMONGO_SECRET_KEY', '').strip()
    if not secret:
        return None
    # base64(secret + ":")
    raw = f'{secret}:'.encode('utf-8')
    return 'Basic ' + base64.b64encode(raw).decode('utf-8')


def _http(method, url, body=None):
    """Make a JSON HTTP call to PayMongo using stdlib. Returns (status, json)."""
    auth = _auth_header()
    if not auth:
        raise RuntimeError('PAYMONGO_SECRET_KEY not configured')

    headers = {
        'Authorization': auth,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
    }
    data_bytes = None
    if body is not None:
        data_bytes = json.dumps(body).encode('utf-8')

    req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            payload = resp.read().decode('utf-8')
            return resp.status, json.loads(payload) if payload else {}
    except urllib.error.HTTPError as e:
        body_text = ''
        try:
            body_text = e.read().decode('utf-8')
        except Exception:
            pass
        try:
            parsed = json.loads(body_text) if body_text else {}
        except Exception:
            parsed = {'raw': body_text}
        return e.code, parsed


def _extract_status(attrs):
    """The Checkout Session's top-level `status` only ever reads 'active' or
    'expired' — PayMongo never sets it to 'paid'. Whether the session is
    actually paid is signalled by the nested payment_intent's status
    ('succeeded') or a non-empty `payments` list, so check those first."""
    payment_intent = attrs.get('payment_intent') or {}
    pi_attrs = payment_intent.get('attributes') or {}
    pi_status = (pi_attrs.get('status') or '').lower()

    payments = []
    for candidate in (attrs.get('payments'), pi_attrs.get('payments')):
        if isinstance(candidate, list):
            payments.extend(candidate)

    if pi_status == 'succeeded' or payments:
        return 'paid'

    session_status = (attrs.get('status') or '').lower()
    if session_status == 'expired':
        return 'expired'
    if pi_status in ('awaiting_payment_method', 'awaiting_next_action', 'processing', ''):
        return 'pending'
    return pi_status or session_status or 'pending'


# ---------------------------------------------------------------------------
# Payment-detail extraction (ported from marilao_new's PayMongo lambda).
# Digs the concrete payment method, paid amount, paid_at timestamp and a stable
# reference out of the nested checkout-session → payment_intent → payments tree
# so the receipt can show the real rail (GCash / card / QRPh …) instead of a
# generic label.
# ---------------------------------------------------------------------------

def _pick_first(*values):
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


def _normalize_payment_method(payment):
    if not isinstance(payment, dict):
        return None
    attributes = payment.get('attributes') or {}
    source = attributes.get('source') or {}
    payment_method = attributes.get('payment_method') or {}
    details = payment_method.get('details') or {}
    return _pick_first(
        attributes.get('payment_method_type'),
        payment_method.get('type'),
        details.get('type'),
        source.get('type'),
        attributes.get('channel_code'),
    )


def _extract_payment_details(attributes, session_id):
    payment_intent = attributes.get('payment_intent') or {}
    pi_attributes = payment_intent.get('attributes') or {}

    payments = []
    for candidate in (
        attributes.get('payments'),
        pi_attributes.get('payments'),
    ):
        if isinstance(candidate, list):
            payments.extend([p for p in candidate if isinstance(p, dict)])

    latest_payment = payments[-1] if payments else {}
    latest_attrs = latest_payment.get('attributes') or {}

    amount_value = _pick_first(
        latest_attrs.get('amount'),
        latest_attrs.get('gross_amount'),
        pi_attributes.get('amount'),
        attributes.get('amount'),
    )
    if amount_value is not None:
        try:
            amount_value = float(amount_value) / 100.0
        except Exception:
            pass

    return {
        'payment_id': _pick_first(
            latest_payment.get('id'),
            payment_intent.get('id'),
            session_id,
        ),
        'reference_no': _pick_first(
            latest_attrs.get('reference_number'),
            latest_attrs.get('reference_no'),
            latest_attrs.get('rrn'),
            latest_payment.get('id'),
            payment_intent.get('id'),
            session_id,
        ),
        'payment_method': _pick_first(
            _normalize_payment_method(latest_payment),
            _pick_first(*(attributes.get('payment_method_types') or [])),
        ),
        'payment_amount': amount_value,
        'paid_at': _pick_first(
            latest_attrs.get('paid_at'),
            latest_attrs.get('updated_at'),
            pi_attributes.get('updated_at'),
            attributes.get('updated_at'),
        ),
    }


def create_paymongo_checkout(cur, data, files, ts):
    try:
        if _auth_header() is None:
            return fail('Payment provider not configured', 500)

        require(data, 'amount_centavos', 'description', 'reference_number',
                'user_profile_id')

        try:
            amount = int(data['amount_centavos'])
        except (TypeError, ValueError):
            return fail('amount_centavos must be an integer (centavos)')
        if amount < 2000:
            return fail('Amount must be at least 2000 centavos (PHP 20.00)')

        description = str(data['description']).strip()
        reference_number = str(data['reference_number']).strip()
        user_id = data['user_profile_id']

        methods_raw = data.get('payment_methods')
        if methods_raw:
            try:
                methods = json.loads(methods_raw) if isinstance(methods_raw, str) else list(methods_raw)
                if not isinstance(methods, list) or not methods:
                    raise ValueError
            except Exception:
                return fail('payment_methods must be a JSON list of strings')
        else:
            methods = ['card', 'gcash', 'grab_pay', 'paymaya']

        success_url = data.get('success_url') or f'{_DEFAULT_SUCCESS_URL}?ref={reference_number}'
        cancel_url = data.get('cancel_url') or f'{_DEFAULT_CANCEL_URL}?ref={reference_number}'

        # Optional billing details (ported from marilao_new). When an email is
        # supplied PayMongo emails a receipt and pre-fills the billing block.
        email_addr = str(data.get('email', '') or '').strip()
        line1 = str(data.get('line1', '') or '').strip()
        city = str(data.get('city', '') or '').strip()

        # Convenience fee (ported from marilao_new, env-driven and OPT-IN).
        # CONVENIENCE_FEE is expressed in PHP (e.g. "25" -> PHP 25.00). Defaults
        # to 0 so existing cebu_lgu charges are unchanged unless configured. When
        # > 0 it is added as a second line item so PayMongo charges base + fee.
        try:
            fee_php = float(os.environ.get('CONVENIENCE_FEE', '0') or '0')
        except (TypeError, ValueError):
            fee_php = 0.0
        fee_centavos = int(round(fee_php * 100))

        line_items = [{
            'currency': 'PHP',
            'amount': amount,
            'name': description[:255] or 'Payment',
            'quantity': 1,
        }]
        if fee_centavos > 0:
            line_items.append({
                'currency': 'PHP',
                'amount': fee_centavos,
                'name': 'Convenience Fee',
                'description': 'Convenience Fee',
                'quantity': 1,
            })

        attributes = {
            'line_items': line_items,
            'payment_method_types': methods,
            'success_url': success_url,
            'cancel_url': cancel_url,
            'description': description[:255],
            'reference_number': reference_number,
            'send_email_receipt': bool(email_addr),
            'show_description': True,
            'show_line_items': True,
        }
        if email_addr or line1 or city:
            attributes['billing'] = {
                'email': email_addr,
                'address': {
                    'line1': line1,
                    'city': city,
                    'country': 'PH',
                },
            }

        body = {'data': {'attributes': attributes}}

        code, resp = _http('POST', f'{_PAYMONGO_BASE}/checkout_sessions', body)
        if code >= 400:
            logger.error('paymongo create failed: %s %s', code, resp)
            msg = 'PayMongo error'
            try:
                msg = resp['errors'][0]['detail']
            except Exception:
                pass
            return fail(msg, 502)

        session = (resp.get('data') or {})
        session_id = session.get('id') or ''
        attrs = session.get('attributes') or {}
        checkout_url = attrs.get('checkout_url') or ''
        status = _extract_status(attrs)

        raw_json = json.dumps(resp)[:65000]  # LONGTEXT but guard size
        cur.execute("""
            INSERT INTO app_paymongo_sessions (
                user_id, reference_number, session_id, checkout_url,
                amount_centavos, currency, status, raw_response, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            user_id, reference_number, session_id, checkout_url,
            amount, 'PHP', status, raw_json, ts,
        ))

        return ok({
            'status': True,
            'message': 'Checkout created',
            'data': {
                'session_id': session_id,
                'checkout_url': checkout_url,
                'status': status,
                'amount_centavos': amount,
                'convenience_fee_centavos': fee_centavos,
                'total_centavos': amount + fee_centavos,
                'currency': 'PHP',
                'reference_number': reference_number,
                'created_at': (ts.isoformat() if isinstance(ts, datetime) else str(ts)),
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error('create_paymongo_checkout error: %s', e, exc_info=True)
        return fail(f'Server error: {e}', 500)


def check_paymongo_status(cur, data, files, ts):
    try:
        if _auth_header() is None:
            return fail('Payment provider not configured', 500)
        require(data, 'session_id')
        session_id = str(data['session_id']).strip()

        code, resp = _http('GET', f'{_PAYMONGO_BASE}/checkout_sessions/{session_id}')
        if code >= 400:
            logger.error('paymongo status failed: %s %s', code, resp)
            msg = 'PayMongo error'
            try:
                msg = resp['errors'][0]['detail']
            except Exception:
                pass
            return fail(msg, 502)

        session = (resp.get('data') or {})
        attrs = session.get('attributes') or {}
        status = _extract_status(attrs)
        checkout_url = attrs.get('checkout_url') or ''
        amount = 0
        try:
            amount = int((attrs.get('line_items') or [{}])[0].get('amount') or 0)
        except Exception:
            amount = 0
        reference_number = attrs.get('reference_number') or ''

        # Concrete payment details (ported from marilao_new): actual rail used,
        # paid amount, paid_at and a stable reference for the receipt.
        details = _extract_payment_details(attrs, session_id)

        # Update local row. If the session isn't tracked locally, still return status.
        paid_at = ts if status == 'paid' else None
        raw_json = json.dumps(resp)[:65000]
        cur.execute("""
            UPDATE app_paymongo_sessions
               SET status=%s, raw_response=%s, updated_at=%s,
                   paid_at=COALESCE(paid_at, %s)
             WHERE session_id=%s
        """, (status, raw_json, ts, paid_at, session_id))

        return ok({
            'status': True,
            'data': {
                'session_id': session_id,
                'checkout_url': checkout_url,
                'status': status,
                'amount_centavos': amount,
                'currency': 'PHP',
                'reference_number': reference_number,
                'is_paid': status == 'paid',
                'payment_method': details.get('payment_method'),
                'payment_amount': details.get('payment_amount'),
                'payment_id': details.get('payment_id'),
                'reference_no': details.get('reference_no'),
                'paid_at': details.get('paid_at'),
                'created_at': (ts.isoformat() if isinstance(ts, datetime) else str(ts)),
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error('check_paymongo_status error: %s', e, exc_info=True)
        return fail(f'Server error: {e}', 500)
