"""Smart-card transaction history.

Each row in `app_card_transactions` is one usage event of a citizen's
assigned card (issuance, top-up, redemption, manual adjustment, …). The
mobile app reads from here to render the "Card Transactions" list under
the digital card on the smart-card screen.

The table is created lazily on first read so the endpoint works even on
environments where migration 016 hasn't been applied yet.
"""

import logging

from helpers.auth import ok, fail, require
from helpers.db import serialize_row
from helpers.forms import parse_int

logger = logging.getLogger()

_DDL = """
CREATE TABLE IF NOT EXISTS app_card_transactions (
    id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id          BIGINT UNSIGNED NOT NULL,
    assign_card      VARCHAR(80)  NOT NULL,
    transaction_type VARCHAR(50)  NOT NULL,
    scanned_by       VARCHAR(150) NULL,
    scanner_id       BIGINT UNSIGNED NULL,
    remarks          TEXT NULL,
    date_created     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cardtx_user (user_id),
    INDEX idx_cardtx_card (assign_card),
    INDEX idx_cardtx_scanner (scanner_id),
    INDEX idx_cardtx_date (date_created)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
"""

# Idempotent column additions for environments where the table predates
# these fields. Each statement no-ops if the column already exists.
_ALTERS = [
    """
    SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'app_card_transactions'
                 AND COLUMN_NAME = 'scanned_by')
    """,
    """
    SET @s := IF(@c = 0,
        'ALTER TABLE app_card_transactions ADD COLUMN scanned_by VARCHAR(150) NULL AFTER transaction_type',
        'SELECT 1')
    """,
    "PREPARE stmt FROM @s",
    "EXECUTE stmt",
    "DEALLOCATE PREPARE stmt",
    """
    SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'app_card_transactions'
                 AND COLUMN_NAME = 'scanner_id')
    """,
    """
    SET @s := IF(@c = 0,
        'ALTER TABLE app_card_transactions ADD COLUMN scanner_id BIGINT UNSIGNED NULL AFTER scanned_by, ADD INDEX idx_cardtx_scanner (scanner_id)',
        'SELECT 1')
    """,
    "PREPARE stmt FROM @s",
    "EXECUTE stmt",
    "DEALLOCATE PREPARE stmt",
]

def _ensure_table(cur):
    cur.execute(_DDL)
    for sql in _ALTERS:
        cur.execute(sql)

def get_card_transactions(cur, data, files, ts):
    """List card transactions for the signed-in user, newest first.

    Optional filters:
      - `assign_card`  : restrict to a specific card number
      - `limit`        : cap rows (default 100, hard max 500)
    """
    try:
        require(data, 'user_profile_id')
        _ensure_table(cur)

        params = [data['user_profile_id']]
        where = "WHERE user_id=%s"
        card = (data.get('assign_card') or '').strip()
        if card:
            where += " AND assign_card=%s"
            params.append(card)

        try:
            limit = int(data.get('limit') or 100)
        except (TypeError, ValueError):
            limit = 100
        limit = max(1, min(limit, 500))

        cur.execute(
            f"""
            SELECT id, user_id, assign_card, transaction_type,
                   scanned_by, scanner_id, remarks, date_created
            FROM app_card_transactions
            {where}
            ORDER BY date_created DESC, id DESC
            LIMIT {limit}
            """,
            tuple(params),
        )
        rows = cur.fetchall()
        return ok({
            'status': True,
            'transactions': [serialize_row(r) for r in rows],
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_card_transactions error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def admin_list_card_transactions(cur, data, files, ts):
    """Admin: cross-user, filterable, paginated list of card transactions."""
    try:
        _ensure_table(cur)

        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit

        user_id = parse_int(data.get('user_id'))
        assign_card = (data.get('assign_card') or '').strip()
        if user_id is None and not assign_card:
            return fail('user_id or assign_card is required')

        where = []
        params = []
        if user_id is not None:
            where.append('user_id=%s')
            params.append(user_id)
        if assign_card:
            where.append('assign_card=%s')
            params.append(assign_card)
        scanner_id = parse_int(data.get('scanner_id'))
        if scanner_id is not None:
            where.append('scanner_id=%s')
            params.append(scanner_id)
        transaction_type = (data.get('transaction_type') or '').strip().upper()
        if transaction_type:
            where.append('transaction_type=%s')
            params.append(transaction_type)
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, user_id, assign_card, transaction_type,
                   scanned_by, scanner_id, remarks, date_created
            FROM app_card_transactions
            {clause}
            ORDER BY date_created DESC, id DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_card_transactions error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
