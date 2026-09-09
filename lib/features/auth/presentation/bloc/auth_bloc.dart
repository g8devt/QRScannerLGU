import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._login, this._logout, this._restoreSession) : super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  final LoginUsecase _login;
  final LogoutUsecase _logout;
  final RestoreSessionUsecase _restoreSession;

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    try {
      final user = await _restoreSession();
      if (user != null) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } on AccountInactiveException catch (e) {
      // The repository already cleared the cached session on a confirmed
      // rejection; clear again here too so a bug in that layer can never
      // leave a stale session behind for the app to keep retrying.
      await _logout();
      emit(AuthState(status: AuthStatus.accountInactive, errorMessage: e.message));
    } on AuthException {
      // Revalidation couldn't reach the backend (offline/timeout/server
      // error). Fail closed -- don't authenticate off a stale cached
      // session -- but this is NOT a confirmed deactivation, so don't
      // show that dialog and don't wipe the cache; a later retry with
      // connectivity can still succeed.
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } catch (_) {
      // Locally cached session was corrupted/unparseable.
      await _logout();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _login(
        username: event.username,
        password: event.password,
        rememberMe: event.rememberMe,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
