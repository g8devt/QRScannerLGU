import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/core/network/api_client.dart';
import 'package:bataan_lgu_scanner/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:bataan_lgu_scanner/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bataan_lgu_scanner/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';

class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource({
    this.response,
    this.error,
    this.checkStatusResponse,
    this.checkStatusError,
  }) : super(ApiClient());
  final Map<String, dynamic>? response;
  final Object? error;
  final Map<String, dynamic>? checkStatusResponse;
  final Object? checkStatusError;
  int? lastCheckedUserId;

  @override
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> checkStatus({required int userId}) async {
    lastCheckedUserId = userId;
    if (checkStatusError != null) throw checkStatusError!;
    return checkStatusResponse!;
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
    test('maps a SUCCESS response to a ScannerUser and caches it locally', () async {
      final local = _FakeAuthLocalDatasource();
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: {
          'status': true,
          'login_status': 'SUCCESS',
          'data': {
            'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED', 'firstname': 'Juan',
            'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
          },
        }),
        local,
      );

      final user = await repo.login(username: 'staff1', password: 'Secret123', rememberMe: true);

      expect(user.id, 7);
      expect(user.username, 'staff1');
      expect(local.stored, isNotNull);
      expect(local.stored!['username'], 'staff1');
    });

    test('does not persist the session when rememberMe is false', () async {
      final local = _FakeAuthLocalDatasource()..stored = {'id': 1};
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: {
          'status': true,
          'login_status': 'SUCCESS',
          'data': {
            'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED', 'firstname': 'Juan',
            'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
          },
        }),
        local,
      );

      final user = await repo.login(username: 'staff1', password: 'Secret123', rememberMe: false);

      expect(user.id, 7);
      expect(local.stored, isNull);
    });

    test('wraps an ApiException as an AuthException', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(error: ApiException('Server error')),
        _FakeAuthLocalDatasource(),
      );

      expect(
        () => repo.login(username: 'staff1', password: 'wrong', rememberMe: true),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Server error')),
      );
    });

    test('throws a generic AuthException on INVALID_CREDENTIAL', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: const {'status': true, 'login_status': 'INVALID_CREDENTIAL'}),
        _FakeAuthLocalDatasource(),
      );

      expect(
        () => repo.login(username: 'staff1', password: 'wrong', rememberMe: true),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Invalid Credential')),
      );
    });

    test('throws AccountInactiveException on INACTIVE and does not cache anything', () async {
      final local = _FakeAuthLocalDatasource();
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: const {'status': true, 'login_status': 'INACTIVE'}),
        local,
      );

      await expectLater(
        repo.login(username: 'staff1', password: 'Secret123', rememberMe: true),
        throwsA(isA<AccountInactiveException>()),
      );
      expect(local.stored, isNull);
    });

    test('throws AccountDeactivatedException on DEACTIVATED and does not cache anything', () async {
      final local = _FakeAuthLocalDatasource();
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: const {'status': true, 'login_status': 'DEACTIVATED'}),
        local,
      );

      await expectLater(
        repo.login(username: 'staff1', password: 'Secret123', rememberMe: true),
        throwsA(isA<AccountDeactivatedException>()),
      );
      expect(local.stored, isNull);
    });
  });

  group('AuthRepositoryImpl.restoreSession', () {
    test('returns null when nothing is cached', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(checkStatusResponse: const {'status': true, 'is_valid': true}),
        _FakeAuthLocalDatasource(),
      );

      expect(await repo.restoreSession(), isNull);
    });

    test('revalidates with the backend and returns the cached ScannerUser when still valid', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final remote = _FakeAuthRemoteDatasource(
        checkStatusResponse: const {'status': true, 'is_valid': true},
      );
      final repo = AuthRepositoryImpl(remote, local);

      final user = await repo.restoreSession();

      expect(user, isNotNull);
      expect(user!.username, 'staff1');
      expect(remote.lastCheckedUserId, 7);
      expect(local.stored, isNotNull);
    });

    test('overlays a changed user_status from the backend onto the returned user '
        'and re-persists it', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(
          checkStatusResponse: const {'status': true, 'is_valid': true, 'user_status': 'PENDING'},
        ),
        local,
      );

      final user = await repo.restoreSession();

      expect(user!.userStatus, 'PENDING');
      expect(local.stored!['user_status'], 'PENDING');
    });

    test('clears the cached session and throws AccountInactiveException when the '
        'backend rejects it with reason INACTIVE', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(
          checkStatusResponse: const {'status': true, 'is_valid': false, 'reason': 'INACTIVE'},
        ),
        local,
      );

      await expectLater(repo.restoreSession(), throwsA(isA<AccountInactiveException>()));
      expect(local.stored, isNull);
    });

    test('clears the cached session and throws AccountDeactivatedException when the '
        'backend rejects it with reason DEACTIVATED', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(
          checkStatusResponse: const {'status': true, 'is_valid': false, 'reason': 'DEACTIVATED'},
        ),
        local,
      );

      await expectLater(repo.restoreSession(), throwsA(isA<AccountDeactivatedException>()));
      expect(local.stored, isNull);
    });

    test('does not clear the cached session and throws AuthException on a network/server failure', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(checkStatusError: ApiException('Server error')),
        local,
      );

      await expectLater(repo.restoreSession(), throwsA(isA<AuthException>()));
      expect(local.stored, isNotNull);
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
