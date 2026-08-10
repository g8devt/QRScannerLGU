import logging

from helpers.auth import ok, fail

logger = logging.getLogger()

_MODULE_TABLES = {
    'business_permits': 'app_business_permits',
    'kyc': 'app_admin_kyc_submissions',
    'incident_reports': 'app_incident_reports',
    'tourism_ipass': 'app_tourism_ipass',
    'social_services': 'app_social_services',
    'civil_registry_births': 'app_birth_registrations',
    'smart_card_registrations': 'app_card_registrations',
    'smart_card_requests': 'app_card_request',
    'job_postings': 'app_job_postings',
}


def _status_counts(cur, table):
    """Return {status_value: count} for one table, grouped by its `status`
    column. Never raises: a query failure on this one table (e.g.
    app_birth_registrations, which has no checked-in DDL anywhere in this
    repo and is the most likely table to not actually exist in the live
    database) is logged and reported as None so it can't take down the
    rest of the dashboard summary. Returns {} on success with zero rows,
    and None on any exception, so callers can tell the two apart."""
    try:
        cur.execute(f"SELECT status, COUNT(*) AS c FROM {table} GROUP BY status")
        rows = cur.fetchall() or []
        return {
            str(r['status']).upper(): (r.get('c') or 0)
            for r in rows if r.get('status') is not None
        }
    except Exception as e:
        logger.warning(f'_status_counts failed for table {table}: {e}')
        return None


def admin_get_dashboard_summary(cur, data, files, ts):
    try:
        summary = {
            module: _status_counts(cur, table)
            for module, table in _MODULE_TABLES.items()
        }
        unavailable = [module for module, counts in summary.items() if counts is None]
        return ok({'status': True, 'data': summary, 'unavailable': unavailable})
    except Exception as e:
        logger.error(f'admin_get_dashboard_summary error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
