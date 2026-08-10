import logging

from helpers.auth import ok, fail

logger = logging.getLogger()

def get_medicines(cur, data, files, ts):
    """
    Return the full list of medicines available for social-service
    assistance. Optional `q` filter for typeahead search.
    """
    try:
        q = (data.get('q') or '').strip()
        # Probe the medicines table columns so we pick up whatever name /
        # label field exists (medicine_name, name, generic_name, …).
        cur.execute("SHOW COLUMNS FROM medicines")
        cols = [r['Field'] for r in cur.fetchall()]
        name_col = None
        for c in ('medicine_name', 'name', 'generic_name', 'brand_name',
                  'product_name', 'description'):
            if c in cols:
                name_col = c
                break
        if not name_col:
            return fail('No known name column on medicines table', 500)

        if q:
            cur.execute(
                f"SELECT DISTINCT `{name_col}` AS name FROM medicines "
                f"WHERE `{name_col}` LIKE %s ORDER BY `{name_col}` ASC LIMIT 500",
                (f'%{q}%',),
            )
        else:
            cur.execute(
                f"SELECT DISTINCT `{name_col}` AS name FROM medicines "
                f"WHERE `{name_col}` IS NOT NULL AND `{name_col}` <> '' "
                f"ORDER BY `{name_col}` ASC LIMIT 2000"
            )
        rows = cur.fetchall()
        return ok({
            'status': True,
            'medicines': [r['name'] for r in rows if r.get('name')],
        })
    except Exception as e:
        logger.error(f'get_medicines: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
