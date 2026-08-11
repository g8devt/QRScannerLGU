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
    try {
      final json = await _remote.login(username: username, password: password);
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
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException('Network error — could not reach the server.');
    }
  }

  @override
  Future<ScannerUser?> restoreSession() async {
    final json = await _local.getSession();
    if (json == null) return null;
    return ScannerUser.fromJson(json);
  }

  @override
  Future<void> logout() => _local.clearSession();
}
