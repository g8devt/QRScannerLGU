// Regression test: AuthGate used to swap LoginPage out for SplashPage
// whenever AuthBloc emitted AuthStatus.loading. That status is only ever
// emitted from a manual LoginRequested submission (never from the
// startup AppStarted/restoreSession flow), so every login attempt --
// successful or not -- unmounted LoginPage mid-submit, destroying its
// TextEditingControllers, then remounted a brand-new LoginPage once the
// result arrived. The user only notices this on a *failed* attempt
// (wrong password, or an inactive/deactivated account): both fields they
// just typed come back empty. Fixed by keeping AuthStatus.loading routed
// to LoginPage (whose _SignInPanel already renders a spinner button for
// it) instead of SplashPage.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/core/network/api_client.dart';
import 'package:bataan_lgu_scanner/features/app_update/data/datasources/app_update_remote_datasource.dart';
import 'package:bataan_lgu_scanner/features/app_update/domain/usecases/check_app_update.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/entities/scanner_user.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/login_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/logout_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/pages/auth_gate.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/pages/login_page.dart';

class _RejectingAuthRepository implements AuthRepository {
  _RejectingAuthRepository(this.loginError);
  final Object loginError;

  @override
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    // A real async round trip, not a synchronous throw -- so the bloc
    // genuinely passes through AuthStatus.loading before the failure,
    // exactly like the production HTTP call does.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw loginError;
  }

  @override
  Future<ScannerUser?> restoreSession() async => null; // nothing cached

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets(
    'the typed username and password survive a failed login attempt',
    (tester) async {
      final repository = _RejectingAuthRepository(AuthException('Invalid Credential'));
      final bloc = AuthBloc(
        LoginUsecase(repository),
        LogoutUsecase(repository),
        RestoreSessionUsecase(repository),
      );
      addTearDown(bloc.close);
      final checkAppUpdate = CheckAppUpdate(AppUpdateRemoteDatasource(ApiClient()));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: AuthGate(checkAppUpdate: checkAppUpdate),
          ),
        ),
      );
      // Reach LoginPage: nothing cached, so AppStarted resolves quickly;
      // let the 3s splash timer elapse.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(LoginPage), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'staff1');
      await tester.enterText(fields.at(1), 'WrongPass');

      await tester.tap(find.text('Log in'));
      // AuthStatus.loading fires on this frame -- this is the exact
      // moment the old code unmounted LoginPage in favor of SplashPage.
      await tester.pump();
      // Let the fake network delay and the rejection resolve.
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        find.byType(LoginPage),
        findsOneWidget,
        reason: 'LoginPage must stay mounted through the loading state, '
            'not be torn down and rebuilt',
      );
      expect(find.text('Invalid Credential'), findsOneWidget);

      final usernameField = tester.widget<TextField>(fields.at(0));
      final passwordField = tester.widget<TextField>(fields.at(1));
      expect(usernameField.controller!.text, 'staff1');
      expect(passwordField.controller!.text, 'WrongPass');
    },
  );
}
