import '../../../../core/network/api_client.dart';
import '../../domain/entities/scanner_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local);

  final AuthRemoteDatasource _remote;
  final AuthLocalDatasource _local;

  @override
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final Map<String, dynamic> json;
    try {
      json = await _remote.login(username: username, password: password);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException('Network error — could not reach the server.');
    }

    // The submitted password must already be verified correct server-side
    // before any of these outcomes other than INVALID_CREDENTIAL is even
    // possible — see login_scanner_bataan. INVALID_CREDENTIAL covers both
    // a wrong password and an unknown username, deliberately
    // indistinguishable here too.
    switch (json['login_status']) {
      case 'INACTIVE':
        throw AccountInactiveException(
          'Your account is no longer active. Please contact your administrator for assistance.',
        );
      case 'DEACTIVATED':
        throw AccountDeactivatedException(
          'Your account has been deactivated. Please contact your administrator for assistance.',
        );
      case 'SUCCESS':
        final data = json['data'] as Map<String, dynamic>? ?? {};
        final user = ScannerUser.fromJson(data);
        if (rememberMe) {
          await _local.saveSession(data);
        } else {
          // Wipe any previously-remembered session so a stale one can't
          // auto-login next launch.
          await _local.clearSession();
        }
        return user;
      case 'INVALID_CREDENTIAL':
      default:
        throw AuthException('Invalid Credential');
    }
  }

  @override
  Future<ScannerUser?> restoreSession() async {
    final json = await _local.getSession();
    if (json == null) return null;

    final Map<String, dynamic> response;
    try {
      response = await _remote.checkStatus(userId: ScannerUser.fromJson(json).id);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException('Network error — could not reach the server.');
    }

    final isValid = response['is_valid'] == true;
    if (!isValid) {
      await _local.clearSession();
      if (response['reason'] == 'DEACTIVATED') {
        throw AccountDeactivatedException(
          'Your account has been deactivated. Please contact your administrator for assistance.',
        );
      }
      throw AccountInactiveException(
        'Your account is no longer active. Please contact your administrator for assistance.',
      );
    }

    // The cached session was captured at login time, so it never sees an
    // admin's later verification-status change (e.g. VERIFIED->PENDING) on
    // its own -- that alone doesn't fail is_valid above. Overlay the fresh
    // user_status this call just returned, and persist it so the cache
    // doesn't keep resurfacing the stale value on the next launch too.
    final refreshed = {...json, 'user_status': response['user_status'] ?? json['user_status']};
    await _local.saveSession(refreshed);
    return ScannerUser.fromJson(refreshed);
  }

  @override
  Future<void> logout() => _local.clearSession();
}
