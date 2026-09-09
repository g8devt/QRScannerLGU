// Regression test for a real production bug: the "Account Inactive" dialog
// never appeared after a deactivated staff member's Remember Me session was
// rejected by the backend. Root cause was a listener-mounting race in
// AuthGate, not the bloc/repository logic (which was already covered by
// auth_bloc_test.dart / auth_repository_impl_test.dart and passed there).
//
// AuthGate used to nest the dialog-showing BlocConsumer *inside* the
// splash/version-check gated branch of build(), so it only subscribed to
// AuthBloc after the 3s splash timer (and, on Android, a version-check
// round trip) completed. restoreSession()'s backend revalidation call is a
// single fast HTTP request that resolves well before that gate opens, so by
// the time the listener finally subscribed, the bloc had *already*
// transitioned to AuthStatus.accountInactive — a transition
// BlocListener/BlocConsumer never replay, since they only report emissions
// that happen after subscription. The dialog was silently skipped every
// single time. The fix hoists the listener to wrap AuthGate's entire build
// output unconditionally, so it subscribes on the very first frame.

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

/// Rejects immediately (a microtask, not a timer) — mirrors the real
/// production shape: restoreSession()'s backend round trip resolves long
/// before AuthGate's 3s splash timer or (on Android) its version check.
class _InstantlyRejectedAuthRepository implements AuthRepository {
  @override
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) => throw UnimplementedError();

  @override
  Future<ScannerUser?> restoreSession() => Future.error(
        AccountInactiveException(
          'Your account is no longer active. Please contact your administrator for assistance.',
        ),
      );

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets(
    'shows the Account Inactive dialog even though the accountInactive '
    'transition happens while AuthGate is still splash-gated',
    (WidgetTester tester) async {
      final bloc = AuthBloc(
        LoginUsecase(_InstantlyRejectedAuthRepository()),
        LogoutUsecase(_InstantlyRejectedAuthRepository()),
        RestoreSessionUsecase(_InstantlyRejectedAuthRepository()),
      );
      final checkAppUpdate = CheckAppUpdate(AppUpdateRemoteDatasource(ApiClient()));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: AuthGate(checkAppUpdate: checkAppUpdate),
          ),
        ),
      );

      // Let restoreSession()'s Future.error resolve and the bloc emit
      // accountInactive. A single pump() already flushes the microtask
      // chain, so the dialog must be showing well before the splash timer
      // (3s) is anywhere near done — this is the moment the bug dropped
      // the transition (the old code didn't even subscribe yet at this
      // point, since it stayed splash-gated for a further ~3s).
      await tester.pump();
      expect(
        find.text('Account Inactive'),
        findsOneWidget,
        reason: 'AuthGate must catch the accountInactive transition even '
            'while still splash-gated, not only after the splash timer '
            'elapses',
      );
      expect(
        find.text(
          'Your account is no longer active. Please contact your administrator for assistance.',
        ),
        findsOneWidget,
      );

      // Dismiss the dialog, then let the splash timer finish — the app
      // should land on LoginPage, never DashboardPage.
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.byType(LoginPage), findsOneWidget);
    },
  );
}
