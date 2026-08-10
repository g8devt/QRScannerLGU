import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/core/network/api_client.dart';
import 'package:bataan_lgu_scanner/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:bataan_lgu_scanner/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bataan_lgu_scanner/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';

class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource({this.response, this.error}) : super(ApiClient());
  final Map<String, dynamic>? response;
  final Object? error;

  @override
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    if (error != null) throw error!;
    return response!;
  }
}

class _FakeAuthLocalDatasource extends AuthLocalDatasource {
  Map<String, dynamic>? stored;

  @override
  Future<void> saveSession(Map<String, dynamic> json) async => stored = json;

  @override
  Future<Map<String, dynamic>?> getSession() async => stored;

  @override
  Future<void> clearSession() async => stored = null;
}

void main() {
  group('AuthRepositoryImpl.login', () {
    test('maps a successful response to a ScannerUser and caches it locally', () async {
      final local = _FakeAuthLocalDatasource();
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: {
          'status': true,
          'data': {
            'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED', 'firstname': 'Juan',
            'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
          },
        }),
        local,
      );

      final user = await repo.login(username: 'staff1', password: 'Secret123');

      expect(user.id, 7);
      expect(user.username, 'staff1');
      expect(local.stored, isNotNull);
      expect(local.stored!['username'], 'staff1');
    });

    test('wraps an ApiException as an AuthException', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(error: ApiException('Invalid Credential')),
        _FakeAuthLocalDatasource(),
      );

      expect(
        () => repo.login(username: 'staff1', password: 'wrong'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Invalid Credential')),
      );
    });
  });

  group('AuthRepositoryImpl.restoreSession', () {
    test('returns null when nothing is cached', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: const {}),
        _FakeAuthLocalDatasource(),
      );

      expect(await repo.restoreSession(), isNull);
    });

    test('returns the cached ScannerUser when present', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(_FakeAuthRemoteDatasource(response: const {}), local);

      final user = await repo.restoreSession();

      expect(user, isNotNull);
      expect(user!.username, 'staff1');
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('clears the local session', () async {
      final local = _FakeAuthLocalDatasource()..stored = {'id': 1};
      final repo = AuthRepositoryImpl(_FakeAuthRemoteDatasource(response: const {}), local);

      await repo.logout();

      expect(local.stored, isNull);
    });
  });
}
