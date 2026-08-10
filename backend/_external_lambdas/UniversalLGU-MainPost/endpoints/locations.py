"""
Location lookup endpoints for PH address dropdowns.
Data lives in `app_locations` (mirrored from marilao_db). The table has
one row per administrative unit: Region / Province / City-Municipality /
Barangay. We filter by parent fields to return only the distinct options
for each cascading dropdown.
"""
import logging

from helpers.auth import ok, fail

logger = logging.getLogger()

def get_regions(cur, data, files, ts):
    try:
        cur.execute("""
            SELECT DISTINCT region
            FROM app_locations
            WHERE region IS NOT NULL AND region <> ''
            ORDER BY region ASC
        """)
        return ok({
            'status': True,
            'regions': [r['region'] for r in cur.fetchall()],
        })
    except Exception as e:
        logger.error(f'get_regions: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_provinces(cur, data, files, ts):
    try:
        region = (data.get('region') or '').strip()
        if not region:
            return fail('Missing region')
        cur.execute("""
            SELECT DISTINCT province
            FROM app_locations
            WHERE region=%s AND province IS NOT NULL AND province <> ''
            ORDER BY province ASC
        """, (region,))
        return ok({
            'status': True,
            'provinces': [r['province'] for r in cur.fetchall()],
        })
    except Exception as e:
        logger.error(f'get_provinces: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_municipalities(cur, data, files, ts):
    try:
        province = (data.get('province') or '').strip()
        if not province:
            return fail('Missing province')
        cur.execute("""
            SELECT DISTINCT city_municipality
            FROM app_locations
            WHERE province=%s AND city_municipality IS NOT NULL
              AND city_municipality <> ''
            ORDER BY city_municipality ASC
        """, (province,))
        return ok({
            'status': True,
            'municipalities': [r['city_municipality'] for r in cur.fetchall()],
        })
    except Exception as e:
        logger.error(f'get_municipalities: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_barangays(cur, data, files, ts):
    try:
        municipality = (data.get('municipality') or '').strip()
        if not municipality:
            return fail('Missing municipality')
        cur.execute("""
            SELECT DISTINCT barangay
            FROM app_locations
            WHERE city_municipality=%s AND barangay IS NOT NULL
              AND barangay <> ''
            ORDER BY barangay ASC
        """, (municipality,))
        return ok({
            'status': True,
            'barangays': [r['barangay'] for r in cur.fetchall()],
        })
    except Exception as e:
        logger.error(f'get_barangays: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
