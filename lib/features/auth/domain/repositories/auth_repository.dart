import '../entities/scanner_user.dart';

abstract class AuthRepository {
  /// Authenticates against `login_scanner_bataan`. Throws
  /// [AuthException] with a human-readable reason on invalid credentials,
  /// a deactivated account, or a network failure.
  Future<ScannerUser> login({required String username, required String password});

  /// Returns the locally cached session, or null if none is stored.
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
