import '../entities/scanner_user.dart';

abstract class AuthRepository {
  /// Authenticates against `login_scanner_bataan`.
  ///
  /// Throws [AuthException] (generic "Invalid Credential") on a wrong
  /// username/password or a network failure — this is deliberately the
  /// same outcome for both, so a caller who doesn't already know the
  /// correct password can never learn whether an account exists or what
  /// its status is. Throws [AccountInactiveException] or
  /// [AccountDeactivatedException] only once the password has been
  /// verified correct for that account, if it is `is_active = 0` or
  /// `user_status = 'DEACTIVATED'` respectively.
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
  /// Throws [AccountInactiveException] or [AccountDeactivatedException]
  /// (and clears the cached session) when the backend confirms the
  /// account is no longer active/deactivated, respectively — the same
  /// distinction [login] makes. Throws [AuthException] on a
  /// network/server failure during revalidation — the cached session is
  /// left untouched so a later retry with connectivity can still succeed.
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

/// Thrown by [AuthRepository.restoreSession] or [AuthRepository.login]
/// when the backend confirms the account is `is_active = 0` (and not
/// `DEACTIVATED` — see [AccountDeactivatedException] for that, which
/// takes priority when both apply). [message] is user-safe (no
/// DB/technical detail) and meant to be shown directly.
class AccountInactiveException implements Exception {
  AccountInactiveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown by [AuthRepository.restoreSession] or [AuthRepository.login]
/// when the backend confirms `user_status = 'DEACTIVATED'`. Kept
/// distinct from [AccountInactiveException] so the UI can show a
/// differently-titled message. [message] is user-safe (no DB/technical
/// detail).
class AccountDeactivatedException implements Exception {
  AccountDeactivatedException(this.message);
  final String message;
  @override
  String toString() => message;
}
