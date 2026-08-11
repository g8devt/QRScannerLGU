import 'package:package_info_plus/package_info_plus.dart';

/// Hardcoded backend config for this single-purpose LGU-staff scanner app.
/// `staffToken` below is a shared app-level token (gates reaching the
/// backend Lambda at all) — distinct from the per-staff username/password
/// login added in `lib/features/auth/`, which authenticates individual
/// staff on top of this.
class AppConfig {
  const AppConfig._();

  /// App version, sourced from the native build at runtime via
  /// [loadPackageInfo]. Empty until loaded (e.g. very early startup or tests).
  static String appVersion = '';

  /// Loads [appVersion] from the platform package metadata (pubspec version).
  /// Call once during app startup, before the UI reads [appVersion].
  static Future<void> initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) appVersion = info.version;
    } catch (_) {
      // Keep the fallback when package info can't be read.
    }
  }

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
