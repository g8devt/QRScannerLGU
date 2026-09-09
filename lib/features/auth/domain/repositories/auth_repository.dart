import '../entities/scanner_user.dart';

abstract class AuthRepository {
  /// Authenticates against `login_scanner_bataan`. Throws
  /// [AuthException] with a human-readable reason on invalid credentials,
  /// a deactivated account, or a network failure.
  ///
  /// The session is persisted locally only when [rememberMe] is true, so
  /// the app auto-logs-in on the next launch only if the user opted in.
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  /// Returns the locally cached session after revalidating it against the
  /// backend's current `is_active`/`user_status` for that account — never
  /// trusts the cached JSON by itself. Returns null if nothing is cached.
  ///
  /// Throws [AccountInactiveException] (and clears the cached session)
  /// when the backend confirms the account is no longer
  /// active/deactivated. Throws [AuthException] on a network/server
  /// failure during revalidation — the cached session is left untouched
  /// so a later retry with connectivity can still succeed.
  Future<ScannerUser?> restoreSession();

  /// Clears the locally cached session.
  Future<void> logout();
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown by [AuthRepository.restoreSession] when the backend confirms
/// the cached account is no longer allowed to access the app
/// (`is_active = 0` or `user_status = 'DEACTIVATED'`). [message] is
/// user-safe (no DB/technical detail) and meant to be shown directly.
class AccountInactiveException implements Exception {
  AccountInactiveException(this.message);
  final String message;
  @override
  String toString() => message;
}
