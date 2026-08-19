import json
import logging
from pymysql.cursors import DictCursor
from helpers.auth import check_token, fail
from helpers.admin_session import verify_admin_token
from helpers.db import get_conn, now_ph, resolve_tenant_db, AUTH_DB
from helpers.parse import parse_event
from endpoints import kyc, social_services, profile, account, preferences, business_permits
from endpoints import social_services_bataan
from endpoints import sanitary_permits, building_permits, inspections, admin_permits
from endpoints import legacy_business_permit
from endpoints import card_registrations, card_transactions, card_qr, card_request, service_toggles, locations, medicines, face_verify
from endpoints import incident_reports, jobs, paymongo
from endpoints import citizen_reports
from endpoints import atty_tony, legal_consultations, migration
from endpoints import district6_ai
from endpoints import cebu_ai
from endpoints import csjdm_ai
from endpoints import emergency
from endpoints import job_openings
from endpoints import notifications
from endpoints import tourism
from endpoints import civil_registry
from endpoints import admin_kyc
from endpoints import kyc_review
from endpoints import audit_log
from endpoints import analytics
from endpoints import scanner_auth_bataan

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# These two endpoints are reached by an applicant who has no session token —
# only the KYC invite_token from the admin-signup plan. submit_admin_kyc
# validates invite_token itself (safe-charset check before it's ever used as
# an S3 key path segment); get_admin_kyc_status only reads by invite_token.
# All other endpoints, including list_kyc_queue, get_kyc_detail, and
# update_kyc_status, continue to require a valid session token exactly as before — db_name/
# tenant DB resolution is still required and unaffected by this bypass.
NO_TOKEN_ENDPOINTS = {
    'submit_admin_kyc', 'get_admin_kyc_status',
    'verify_invite_token', 'accept_invite_set_pin',
}

# Each entry maps an endpoint name to the admin_auth permission a STAFF
# admin must hold to call it -- checked via _check_admin_session, on top
# of (not instead of) the existing app-wide token check every endpoint in
# this file already requires. role=ADMIN always bypasses this regardless
# of the mapped permission. universal_main_post has no cookie-reading
# mechanism (different API Gateway domain than admin_auth), so this is
# header-based, not cookie-based.
ADMIN_SESSION_REQUIRED_ENDPOINTS = {
    'list_kyc_queue': 'kyc_review',
    'get_kyc_detail': 'kyc_review',
    'update_kyc_status': 'kyc_review',
    'fetch_all_permits': 'business_permits',
    'fetch_permit_status_counts': 'business_permits',
    'admin_review_permit': 'business_permits',
    'verify_permit_qr': 'business_permits',
    'fetch_permit_map': 'business_permits',
    'admin_list_business_links': 'business_permits',
    'admin_review_business_link': 'business_permits',
    'admin_list_incident_reports': 'incident_reports',
    'admin_get_incident_report_detail': 'incident_reports',
    'admin_update_incident_status': 'incident_reports',
    'admin_delete_incident_report': 'incident_reports',
    'admin_assess_permit': 'business_permits',
    'admin_list_audit_log': 'audit_logs',
    'admin_list_ipass': 'tourism_ipass',
    'admin_get_ipass_detail': 'tourism_ipass',
    'admin_delete_ipass': 'tourism_ipass',
    'verify_ipass_qr': 'tourism_ipass',
    'upload_tourism_images': 'tourism_destinations',
    'admin_create_destination': 'tourism_destinations',
    'admin_list_destinations': 'tourism_destinations',
    'admin_get_destination_detail': 'tourism_destinations',
    'admin_get_booking_detail': 'tourism_destinations',
    'admin_update_destination': 'tourism_destinations',
    'admin_delete_destination': 'tourism_destinations',
    'admin_create_room': 'tourism_destinations',
    'admin_update_room': 'tourism_destinations',
    'admin_delete_room': 'tourism_destinations',
    'upload_room_image': 'tourism_destinations',
    'admin_list_social_services': 'social_services',
    'admin_update_social_service_status': 'social_services',
    'admin_get_social_service_detail': 'social_services',
    'admin_update_social_service_type': 'social_services',
    'admin_create_social_service': 'social_services',
    'admin_delete_social_service': 'social_services',
    'admin_list_birth_registrations': 'civil_registry',
    'admin_review_birth_registration': 'civil_registry',
    'admin_list_card_registrations': 'smart_card',
    'admin_review_card_registration': 'smart_card',
    'admin_list_job_postings': 'job_applications',
    'admin_get_job_posting_detail': 'job_applications',
    'admin_review_job_posting': 'job_applications',
    'admin_update_job_posting': 'job_applications',
    'admin_delete_job_posting': 'job_applications',
    'admin_list_card_transactions': 'smart_card',
    'admin_list_card_requests': 'smart_card',
    'admin_review_card_request': 'smart_card',
    'admin_send_notification': 'notifications',
    'admin_list_notifications': 'notifications',
    'admin_delete_notification': 'notifications',
    'admin_get_dashboard_summary': 'analytics',
    # None means "ADMIN role only, no STAFF permission can satisfy it" --
    # this is a cross-domain global config write (it touches toggles for
    # business permits, social services, job applications, and card
    # registration all at once) with no single natural permission owner,
    # so it deliberately bypasses the permission-string system entirely
    # rather than being mapped to one domain's permission by convenience.
    'update_service_toggles': None,
}

ROUTES = {
    'submit_kyc': kyc.submit_kyc,
    'get_kyc_status': kyc.get_kyc_status,
    'scan_id': kyc.scan_id,
    'submit_admin_kyc': admin_kyc.submit_admin_kyc,
    'get_admin_kyc_status': admin_kyc.get_admin_kyc_status,
    'list_kyc_queue': kyc_review.list_kyc_queue,
    'get_kyc_detail': kyc_review.get_kyc_detail,
    'update_kyc_status': kyc_review.update_kyc_status,
    'verify_invite_token': admin_kyc.verify_invite_token,
    'accept_invite_set_pin': admin_kyc.accept_invite_set_pin,
    'submit_social_service': social_services.submit_social_service,
    'get_social_services': social_services.get_social_services,
    'admin_list_social_services': social_services.admin_list_social_services,
    'admin_update_social_service_status': social_services.admin_update_social_service_status,
    'admin_get_social_service_detail': social_services.admin_get_social_service_detail,
    'admin_update_social_service_type': social_services.admin_update_social_service_type,
    'admin_create_social_service': social_services.admin_create_social_service,
    'admin_delete_social_service': social_services.admin_delete_social_service,
    'submit_social_service_bataan': social_services_bataan.submit_social_service_bataan,
    'get_social_services_bataan': social_services_bataan.get_social_services_bataan,
    'verify_qr_bataan': social_services_bataan.verify_qr_bataan,
    'get_service_details_bataan': social_services_bataan.get_service_details_bataan,
    'submit_claim_bataan': social_services_bataan.submit_claim_bataan,
    'request_profile_update': profile.request_profile_update,
    'get_user_profile': profile.get_user_profile,
    'get_profile_update_requests': profile.get_profile_update_requests,
    'log_account_deletion': account.log_account_deletion,
    'register_fcm_token': account.register_fcm_token,
    'unregister_fcm_token': account.unregister_fcm_token,
    'get_user_preferences': preferences.get_user_preferences,
    'update_user_preferences': preferences.update_user_preferences,
    'submit_business_permit': business_permits.submit_business_permit,
    'submit_business_permit_renewal': business_permits.submit_business_permit_renewal,
    'submit_business_permit_closure': business_permits.submit_business_permit_closure,
    'get_business_permits': business_permits.get_business_permits,
    'get_business_permit_detail': business_permits.get_business_permit_detail,
    'submit_card_registration': card_registrations.submit_card_registration,
    'get_card_registrations': card_registrations.get_card_registrations,
    'get_card_registration_detail': card_registrations.get_card_registration_detail,
    'admin_list_card_registrations': card_registrations.admin_list_card_registrations,
    'admin_review_card_registration': card_registrations.admin_review_card_registration,
    'get_card_transactions': card_transactions.get_card_transactions,
    'admin_list_card_transactions': card_transactions.admin_list_card_transactions,
    'get_card_qr': card_qr.get_card_qr,
    'request_card_link': card_request.request_card_link,
    'get_card_request_status': card_request.get_card_request_status,
    'admin_list_card_requests': card_request.admin_list_card_requests,
    'admin_review_card_request': card_request.admin_review_card_request,
    'get_service_toggles': service_toggles.get_service_toggles,
    'update_service_toggles': service_toggles.update_service_toggles,
    'get_regions': locations.get_regions,
    'get_provinces': locations.get_provinces,
    'get_municipalities': locations.get_municipalities,
    'get_barangays': locations.get_barangays,
    'get_medicines': medicines.get_medicines,
    'verify_face_match': face_verify.verify_face_match,
    'submit_incident_report': incident_reports.submit_incident_report,
    'list_incident_reports': incident_reports.list_incident_reports,
    'admin_list_incident_reports': incident_reports.admin_list_incident_reports,
    'admin_get_incident_report_detail': incident_reports.admin_get_incident_report_detail,
    'admin_update_incident_status': incident_reports.admin_update_incident_status,
    'admin_delete_incident_report': incident_reports.admin_delete_incident_report,
    'admin_list_audit_log': audit_log.admin_list_audit_log,
    'submit_citizen_report': citizen_reports.submit_citizen_report,
    'list_citizen_reports': citizen_reports.list_citizen_reports,
    'get_citizen_report': citizen_reports.get_citizen_report,
    'cancel_citizen_report': citizen_reports.cancel_citizen_report,
    'post_citizen_message': citizen_reports.post_citizen_message,
    'respond_citizen_report': citizen_reports.respond_citizen_report,
    'save_business_permit_draft': business_permits.save_business_permit_draft,
    'list_business_permit_drafts': business_permits.list_business_permit_drafts,
    'get_business_permit_draft': business_permits.get_business_permit_draft,
    'delete_business_permit_draft': business_permits.delete_business_permit_draft,
    'submit_business_link': business_permits.submit_business_link,
    'admin_assess_permit': business_permits.admin_assess_permit,
    'confirm_business_permit_payment': business_permits.confirm_business_permit_payment,
    'submit_birth_registration': civil_registry.submit_birth_registration,
    'get_birth_registrations': civil_registry.get_birth_registrations,
    'get_birth_registration_detail': civil_registry.get_birth_registration_detail,
    'save_birth_registration_draft': civil_registry.save_birth_registration_draft,
    'list_birth_registration_drafts': civil_registry.list_birth_registration_drafts,
    'get_birth_registration_draft': civil_registry.get_birth_registration_draft,
    'delete_birth_registration_draft': civil_registry.delete_birth_registration_draft,
    'admin_list_birth_registrations': civil_registry.admin_list_birth_registrations,
    'admin_review_birth_registration': civil_registry.admin_review_birth_registration,
    'submit_marriage_license_application': civil_registry.submit_marriage_license_application,
    'get_marriage_license_applications': civil_registry.get_marriage_license_applications,
    'get_marriage_license_application_detail': civil_registry.get_marriage_license_application_detail,
    'save_marriage_license_draft': civil_registry.save_marriage_license_draft,
    'list_marriage_license_drafts': civil_registry.list_marriage_license_drafts,
    'get_marriage_license_draft': civil_registry.get_marriage_license_draft,
    'delete_marriage_license_draft': civil_registry.delete_marriage_license_draft,
    'insert_business_permit': legacy_business_permit.insert_business_permit,
    'get_my_businesses': legacy_business_permit.get_my_businesses,
    'get_business_detail': legacy_business_permit.get_business_detail,
    'renew_business_application': legacy_business_permit.renew_business_application,
    'retire_business_application': legacy_business_permit.retire_business_application,
    'submit_cho_sanitary': sanitary_permits.submit_cho_sanitary,
    'list_cho_sanitary': sanitary_permits.list_cho_sanitary,
    'get_cho_sanitary_detail': sanitary_permits.get_cho_sanitary_detail,
    'submit_obo_building': building_permits.submit_obo_building,
    'list_obo_building': building_permits.list_obo_building,
    'get_obo_building_detail': building_permits.get_obo_building_detail,
    'fetch_inspector_worklist': inspections.fetch_inspector_worklist,
    'submit_inspection': inspections.submit_inspection,
    'get_inspection_detail': inspections.get_inspection_detail,
    'fetch_all_permits': admin_permits.fetch_all_permits,
    'fetch_permit_status_counts': admin_permits.fetch_permit_status_counts,
    'admin_review_permit': admin_permits.admin_review_permit,
    'verify_permit_qr': admin_permits.verify_permit_qr,
    'fetch_permit_map': admin_permits.fetch_permit_map,
    'admin_list_business_links': admin_permits.admin_list_business_links,
    'admin_review_business_link': admin_permits.admin_review_business_link,
    'list_job_postings': jobs.list_job_postings,
    'admin_list_job_postings': jobs.admin_list_job_postings,
    'admin_get_job_posting_detail': jobs.admin_get_job_posting_detail,
    'admin_review_job_posting': jobs.admin_review_job_posting,
    'admin_update_job_posting': jobs.admin_update_job_posting,
    'admin_delete_job_posting': jobs.admin_delete_job_posting,
    'list_jobs_universal': jobs.list_jobs_universal,
    'get_job_posting_detail': jobs.get_job_posting_detail,
    'get_job_favorites': jobs.get_job_favorites,
    'toggle_job_favorite': jobs.toggle_job_favorite,
    'submit_job_application': jobs.submit_job_application,
    'update_job_application': jobs.update_job_application,
    'check_job_application_status': jobs.check_job_application_status,
    'apply_to_job': jobs.apply_to_job,
    'update_job_profile': jobs.update_job_profile,
    'get_job_application': jobs.get_job_application,
    'list_my_job_applications': jobs.list_my_job_applications,
    'get_applicant_profile': jobs.get_applicant_profile,
    'save_applicant_profile': jobs.save_applicant_profile,
    'create_paymongo_checkout': paymongo.create_paymongo_checkout,
    'check_paymongo_status': paymongo.check_paymongo_status,
    # Bataan-branch additions
    'atty_tony_chat': atty_tony.atty_tony_chat,
    'submit_legal_consultation': legal_consultations.submit_legal_consultation,
    'list_my_legal_consultations': legal_consultations.list_my_legal_consultations,
    'get_legal_consultation_detail': legal_consultations.get_legal_consultation_detail,
    # Migration: district_6_db → bataan_db (remove from ROUTES when done)
    'migrate_check': migration.migrate_check,
    'migrate_run':   migration.migrate_run,
    # District 6 branch additions
    'district6_ai_chat': district6_ai.district6_ai_chat,
    # Cebu branch: LGU services AI assistant (Gemini)
    'cebu_ai_chat': cebu_ai.cebu_ai_chat,
    # CSJDM branch: LGU services AI assistant (Gemini)
    'csjdm_ai_chat': csjdm_ai.csjdm_ai_chat,
    # AI-assisted emergency triage (hotline picker, never invents numbers)
    'emergency_triage': emergency.emergency_triage,
    # Public PhilJobnet job openings (scraped, cached)
    'list_job_openings': job_openings.list_job_openings,
    # Notifications — universal (saved to app_notifications in the tenant DB)
    'save_notification': notifications.save_notification,
    'send_notification': notifications.send_notification,
    'list_notifications': notifications.list_notifications,
    'mark_notification_read': notifications.mark_notification_read,
    'mark_all_notifications_read': notifications.mark_all_notifications_read,
    'delete_notification': notifications.delete_notification,
    'admin_send_notification': notifications.admin_send_notification,
    'admin_list_notifications': notifications.admin_list_notifications,
    'admin_delete_notification': notifications.admin_delete_notification,
    'admin_get_dashboard_summary': analytics.admin_get_dashboard_summary,
    'get_tourism_services': tourism.get_tourism_services,
    'get_tourism_destinations': tourism.get_tourism_destinations,
    'upload_tourism_images': tourism.upload_tourism_images,
    'submit_tourism_ipass': tourism.submit_tourism_ipass,
    'get_tourism_ipass': tourism.get_tourism_ipass,
    'check_tourism_ipass': tourism.check_tourism_ipass,
    'admin_list_ipass': tourism.admin_list_ipass,
    'admin_get_ipass_detail': tourism.admin_get_ipass_detail,
    'admin_delete_ipass': tourism.admin_delete_ipass,
    'verify_ipass_qr': tourism.verify_ipass_qr,
    'get_tourism_favorites': tourism.get_tourism_favorites,
    'toggle_tourism_favorite': tourism.toggle_tourism_favorite,
    'admin_create_destination': tourism.admin_create_destination,
    'admin_list_destinations': tourism.admin_list_destinations,
    'admin_get_destination_detail': tourism.admin_get_destination_detail,
    'admin_get_booking_detail': tourism.admin_get_booking_detail,
    'admin_update_destination': tourism.admin_update_destination,
    'admin_delete_destination': tourism.admin_delete_destination,
    'admin_create_room': tourism.admin_create_room,
    'admin_update_room': tourism.admin_update_room,
    'admin_delete_room': tourism.admin_delete_room,
    'upload_room_image': tourism.upload_room_image,
    'get_tourism_rooms': tourism.get_tourism_rooms,
    'quote_tourism_booking': tourism.quote_tourism_booking,
    'create_tourism_booking': tourism.create_tourism_booking,
    'get_tourism_bookings': tourism.get_tourism_bookings,
    'check_tourism_booking': tourism.check_tourism_booking,
    'cancel_tourism_booking': tourism.cancel_tourism_booking,
    'confirm_tourism_booking_payment': tourism.confirm_tourism_booking_payment,
    'login_scanner_bataan': scanner_auth_bataan.login_scanner_bataan,
}


def _check_admin_session(event, cur, tenant_db, required_permission, data=None):
    if tenant_db != 'cebu_lgu_db':
        return fail('This endpoint is only available for cebu_lgu_db', 403)

    headers = event.get('headers') or {}
    auth_header = None
    for k, v in headers.items():
        if k.lower() == 'authorization':
            auth_header = v
            break

    if not auth_header or not auth_header.startswith('Bearer '):
        return fail('Unauthorized', 401)

    token = auth_header[len('Bearer '):]
    claims = verify_admin_token(token)
    if not claims:
        return fail('Unauthorized', 401)

    cur.execute(
        "SELECT role, permissions, is_active, must_change_password "
        "FROM app_admins WHERE id=%s",
        (claims.get('admin_id'),),
    )
    admin = cur.fetchone()
    if not admin or not admin.get('is_active'):
        return fail('Unauthorized', 401)

    if admin.get('must_change_password'):
        return fail('Password change required', 403)

    if admin['role'] == 'ADMIN':
        if data is not None:
            data['_admin'] = {'id': claims.get('admin_id'), 'role': admin['role']}
        return None

    # required_permission=None means "ADMIN role only" (see
    # ADMIN_SESSION_REQUIRED_ENDPOINTS's use of None for update_service_toggles)
    # -- reject every STAFF admin outright rather than falling through to the
    # `in permissions` check below, which would otherwise be bypassable by a
    # permissions column somehow containing a JSON null (e.g. via direct DB
    # access bypassing this codebase's own application-level validation).
    if required_permission is None:
        return fail('Forbidden', 403)

    try:
        permissions = json.loads(admin.get('permissions') or '[]')
    except (ValueError, TypeError):
        permissions = []
    if not isinstance(permissions, list):
        permissions = []
    if required_permission in permissions:
        if data is not None:
            data['_admin'] = {'id': claims.get('admin_id'), 'role': admin['role']}
        return None

    return fail('Forbidden', 403)


def lambda_handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return {'statusCode': 200, 'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        }, 'body': ''}
    try:
        data, files = parse_event(event)
        endpoint = data.get('endpoint')
        token = data.get('token')
        db_name = data.get('db_name')
        bypass_token = endpoint in NO_TOKEN_ENDPOINTS
        if not endpoint or (not token and not bypass_token):
            return fail('Missing endpoint or token')
        # Resolve the tenant DB up front so an unknown db_name is rejected
        # before we touch any connection (e.g. cebu_lgu_db is allowed,
        # arbitrary names are not). This still applies to the two
        # invite_token-only endpoints — only the session token check is
        # bypassed for them.
        tenant_db = resolve_tenant_db(db_name)
        if bypass_token:
            conn = get_conn(tenant_db)
        else:
            # Always authenticate against the shared identity DB (token table
            # lives there); AUTH_DB defaults to universal_lgu_db.
            auth_conn = check_token(token, AUTH_DB)
            if not auth_conn:
                return fail('Access Denied', 403)
            # Run actual queries against the requested tenant DB (e.g. cebu_lgu_db).
            if tenant_db != AUTH_DB:
                conn = get_conn(tenant_db)
            else:
                conn = auth_conn
        cur = conn.cursor(DictCursor)
        ts = now_ph().strftime('%Y-%m-%d %H:%M:%S')
        handler = ROUTES.get(endpoint)
        if not handler:
            return fail(f'Unknown endpoint: {endpoint}')

        if endpoint in ADMIN_SESSION_REQUIRED_ENDPOINTS:
            session_error = _check_admin_session(
                event, cur, tenant_db, ADMIN_SESSION_REQUIRED_ENDPOINTS[endpoint], data=data)
            if session_error:
                return session_error

        return handler(cur, data, files, ts)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
