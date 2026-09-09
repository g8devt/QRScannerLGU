// Covers the title/message branching AuthGate's dialog listener does for
// AuthStatus.accountInactive vs AuthStatus.accountDeactivated -- not
// exercised by the bloc-level tests (those only assert AuthState, not
// which dialog copy AuthGate picks for it).

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
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_event.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/pages/auth_gate.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/pages/login_page.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.loginError);
  final Object loginError;

  @override
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) => throw loginError;

  @override
  Future<ScannerUser?> restoreSession() async => null; // nothing cached

  @override
  Future<void> logout() async {}
}

Future<AuthBloc> _pumpAuthGate(WidgetTester tester, Object loginError) async {
  final repository = _FakeAuthRepository(loginError);
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
  // Nothing is cached, so AppStarted resolves to unauthenticated quickly;
  // let the splash timer elapse to reach LoginPage before logging in.
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  expect(find.byType(LoginPage), findsOneWidget);
  return bloc;
}

void main() {
  testWidgets('shows "Account Inactive" for an INACTIVE manual login rejection', (tester) async {
    final bloc = await _pumpAuthGate(
      tester,
      AccountInactiveException(
        'Your account is no longer active. Please contact your administrator for assistance.',
      ),
    );

    bloc.add(const LoginRequested(username: 'staff1', password: 'Secret123'));
    // Two state transitions happen for this event (loading, then
    // accountInactive) -- pump twice so both are flushed and the widget
    // tree reflects the final one before asserting.
    await tester.pump();
    await tester.pump();

    expect(find.text('Account Inactive'), findsOneWidget);
    expect(find.text('Account Deactivated'), findsNothing);
    expect(
      find.text('Your account is no longer active. Please contact your administrator for assistance.'),
      findsOneWidget,
    );
  });

  testWidgets('shows "Account Deactivated" for a DEACTIVATED manual login rejection', (tester) async {
    final bloc = await _pumpAuthGate(
      tester,
      AccountDeactivatedException(
        'Your account has been deactivated. Please contact your administrator for assistance.',
      ),
    );

    bloc.add(const LoginRequested(username: 'staff1', password: 'Secret123'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Account Deactivated'), findsOneWidget);
    expect(find.text('Account Inactive'), findsNothing);
    expect(
      find.text('Your account has been deactivated. Please contact your administrator for assistance.'),
      findsOneWidget,
    );
  });
}
