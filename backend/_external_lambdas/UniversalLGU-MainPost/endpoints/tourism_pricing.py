# backend/functions/universal_main_post/endpoints/tourism_pricing.py
"""Pure price math for tourism iPass orders. No DB / framework imports so it is
unit-testable offline and the server stays the single source of truth for
money — client-sent totals are never trusted."""


def _unit_price(svc, tier):
    tier = (tier or 'LOCAL').upper()
    price = svc.get('price_foreign') if tier == 'FOREIGN' else svc.get('price_local')
    if price is None:
        raise ValueError(f"No {tier} price for service {svc.get('code')}")
    return float(price)


def _line(svc_id, svc, quantity, tier, variant_label=None):
    qty = int(quantity or 0)
    unit = _unit_price(svc, tier)
    return {
        'service_id': svc_id,
        'service_code': svc.get('code'),
        'service_name': svc.get('name'),
        'unit_price': unit,
        'quantity': qty,
        'line_total': round(unit * qty, 2),
        'variant_label': variant_label,
    }


def compute_ipass_lines(catalog_by_id, service_lines, convenience_service=None):
    """Return (lines, subtotal). Each input line is {service_id, quantity, tier,
    variant_label?}. Appends the convenience service (if given) as one FLAT line
    of quantity 1. Raises ValueError on unknown id or missing tier price."""
    lines = []
    subtotal = 0.0
    for item in service_lines or []:
        sid = int(item['service_id'])
        svc = catalog_by_id.get(sid)
        if svc is None:
            raise ValueError(f"Unknown service id: {sid}")
        line = _line(sid, svc, item.get('quantity', 0),
                     item.get('tier', 'LOCAL'), item.get('variant_label'))
        subtotal += line['line_total']
        lines.append(line)
    if convenience_service is not None:
        cid = int(convenience_service['id'])
        line = _line(cid, convenience_service, 1, 'LOCAL')
        subtotal += line['line_total']
        lines.append(line)
    return lines, round(subtotal, 2)


def compute_totals(subtotal, discount):
    return round(float(subtotal) - float(discount or 0), 2)


# ── Destination booking pricing ──────────────────────────────────────────────
PROMO_CODES = {'CEBU10': 0.10}
TOURISM_TAX_PER_NIGHT = 18.00
VAT_RATE = 0.12


def compute_booking_total(nightly_rate, nights, promo_code=None,
                          room_upgrade_discount=0.0):
    """Pure price math for a resort booking. Server is the single source of
    truth — client-sent totals are never trusted. Unknown promo codes apply no
    discount (no error). Returns the full breakdown as a dict."""
    nights = max(1, int(nights or 1))
    nightly = round(float(nightly_rate or 0), 2)
    room_subtotal = round(nightly * nights, 2)
    code = (promo_code or '').strip().upper() or None
    pct = PROMO_CODES.get(code, 0.0)
    promo_discount = round(room_subtotal * pct, 2)
    upgrade = round(float(room_upgrade_discount or 0), 2)
    taxable = round(room_subtotal - upgrade - promo_discount, 2)
    tourism_tax = round(TOURISM_TAX_PER_NIGHT * nights, 2)
    vat = round(taxable * VAT_RATE, 2)
    total = round(taxable + tourism_tax + vat, 2)
    return {
        'nights': nights,
        'nightly_rate': nightly,
        'room_subtotal': room_subtotal,
        'room_upgrade_discount': upgrade,
        'promo_code': code,
        'promo_discount': promo_discount,
        'tourism_tax': tourism_tax,
        'vat': vat,
        'total': total,
    }
