/// Hardcoded backend config for this single-purpose LGU-staff scanner app.
/// There is no login flow yet — replacing this with real staff
/// authentication is tracked as future work, not part of this feature.
class AppConfig {
  const AppConfig._();

  /// Base URL of the single-Lambda backend (API Gateway `/main` route,
  /// Prod stage — confirmed live, integrates with the UniversalLGU-MainPost
  /// Lambda function).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://h9yltujhgi.execute-api.ap-southeast-1.amazonaws.com/Prod/main',
  );

  /// Tenant database name, sent as `db_name` in every request envelope.
  static const String dbName = 'bataan_db';

  /// Staff session token, sent as `token` in every request envelope.
  /// `check_token` (backend `helpers/auth.py`) strips the first 13
  /// characters before comparing against `app_user_operations_tbl` —
  /// confirmed live: the stripped suffix `universal_lgu_app_token_2025`
  /// matches a stored token value.
  static const String staffToken = String.fromEnvironment(
    'STAFF_TOKEN',
    defaultValue: '1234567890123universal_lgu_app_token_2025',
  );
}
