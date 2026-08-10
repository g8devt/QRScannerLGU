"""Helpers for whitelisted, type-coerced dynamic INSERTs from a form_data map.

Used by the sub-permit endpoints (CHO sanitary, OBO building) which have many
nullable columns and submit only a subset per application type. Only columns in
the caller's whitelist are ever written — unknown form keys are ignored.
"""
import json

from helpers.db import sanitize


def parse_int(v):
    if v in (None, ''):
        return None
    try:
        return int(v)
    except Exception:
        return None


def parse_decimal(v):
    if v in (None, ''):
        return None
    try:
        return float(v)
    except Exception:
        return None


def _coerce(col, val, ints, decimals, dates, lists):
    if col in ints:
        return parse_int(val)
    if col in decimals:
        return parse_decimal(val)
    if col in dates:
        s = str(val).strip() if val is not None else ''
        return s or None
    if col in lists:
        return json.dumps(val) if isinstance(val, list) else sanitize(val)
    return sanitize(val)


def insert_whitelisted(cur, table, form, columns, system,
                       ints=frozenset(), decimals=frozenset(),
                       dates=frozenset(), lists=frozenset()):
    """
    INSERT into `table` the whitelisted `columns` present in `form` (type-coerced)
    plus the forced `system` columns (dict col->value). Returns the new row id.
    """
    cols, vals = [], []
    for col in columns:
        if col in form:
            cols.append(col)
            vals.append(_coerce(col, form.get(col), ints, decimals, dates, lists))
    for col, val in system.items():
        cols.append(col)
        vals.append(val)
    placeholders = ', '.join(['%s'] * len(cols))
    collist = ', '.join('`{}`'.format(c) for c in cols)
    cur.execute(
        "INSERT INTO {} ({}) VALUES ({})".format(table, collist, placeholders),
        tuple(vals),
    )
    return cur.lastrowid
