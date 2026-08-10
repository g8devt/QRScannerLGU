"""Smart-card QR lookup.

The mobile app's digital card needs the real scannable QR payload rather
than the raw card number. A user's `assign_card` value is the primary-key
`id` of a row in the `app_qr_code` pool table; this endpoint resolves that
id to the row's `qr_code` string.
"""

import logging

from helpers.auth import ok, fail, require

logger = logging.getLogger()


def get_card_qr(cur, data, files, ts):
    """Return the `qr_code` payload for the caller's assigned card.

    Requires `assign_card` — the id of the `app_qr_code` row issued to the
    user. Responds with `{status, qr_code}` on success.
    """
    try:
        require(data, 'assign_card')
        assign_card = (data.get('assign_card') or '').strip()
        if not assign_card:
            return fail('Missing assign_card')

        cur.execute(
            "SELECT qr_code FROM app_qr_code WHERE id=%s LIMIT 1",
            (assign_card,),
        )
        row = cur.fetchone()
        if not row or not (row.get('qr_code') or '').strip():
            return fail('QR code not found for assigned card', 404)

        return ok({'status': True, 'qr_code': row['qr_code']})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_card_qr error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)