import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/entities/scanner_user.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/login_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/logout_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_event.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  ScannerUser? loginResult;
  Object? loginError;
  ScannerUser? restoredSession;
  bool loggedOut = false;

  @override
  Future<ScannerUser> login({required String username, required String password}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<ScannerUser?> restoreSession() async => restoredSession;

  @override
  Future<void> logout() async => loggedOut = true;
}

const _user = ScannerUser(
  id: 7, username: 'staff1', userStatus: 'VERIFIED',
  firstname: 'Juan', middlename: '', lastname: 'Dela Cruz', suffix: '',
);

void main() {
  late _FakeAuthRepository repository;
  late AuthBloc bloc;

  setUp(() {
    repository = _FakeAuthRepository();
    bloc = AuthBloc(
      LoginUsecase(repository),
      LogoutUsecase(repository),
      RestoreSessionUsecase(repository),
    );
  });

  tearDown(() => bloc.close());

  test('AppStarted emits authenticated when a session is cached', () async {
    repository.restoredSession = _user;
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AppStarted());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [const AuthState(status: AuthStatus.authenticated, user: _user)]);
  });

  test('AppStarted emits unauthenticated when no session is cached', () async {
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AppStarted());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [const AuthState(status: AuthStatus.unauthenticated)]);
  });

  test('LoginRequested emits loading then authenticated on success', () async {
    repository.loginResult = _user;
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LoginRequested(username: 'staff1', password: 'Secret123'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      const AuthState(status: AuthStatus.loading),
      const AuthState(status: AuthStatus.authenticated, user: _user),
    ]);
  });

  test('LoginRequested emits loading then error on invalid credentials', () async {
    repository.loginError = AuthException('Invalid Credential');
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LoginRequested(username: 'staff1', password: 'wrong'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      const AuthState(status: AuthStatus.loading),
      const AuthState(status: AuthStatus.error, errorMessage: 'Invalid Credential'),
    ]);
  });

  test('LogoutRequested clears the session and emits unauthenticated', () async {
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LogoutRequested());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(repository.loggedOut, isTrue);
    expect(states, [const AuthState(status: AuthStatus.unauthenticated)]);
  });
}
