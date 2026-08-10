/// Hardcoded backend config for this single-purpose LGU-staff scanner app.
/// There is no login flow yet — replacing this with real staff
/// authentication is tracked as future work, not part of this feature.
class AppConfig {
  const AppConfig._();

  /// Base URL of the single-Lambda backend (API Gateway endpoint).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://REPLACE_WITH_API_GATEWAY_URL',
  );

  /// Tenant database name, sent as `db_name` in every request envelope.
  static const String dbName = 'bataan_db';

  /// Staff session token, sent as `token` in every request envelope.
  static const String staffToken = String.fromEnvironment(
    'STAFF_TOKEN',
    defaultValue: 'REPLACE_WITH_STAFF_TOKEN',
  );
}
