import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../splash/presentation/pages/splash_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';

/// Shown as the app's `home`. Dispatches [AppStarted] once, then swaps
/// between [LoginPage] and [DashboardPage] based on auth status.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _splashDuration = Duration(seconds: 3);

  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AppStarted());
    Future.delayed(_splashDuration, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return const SplashPage();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const DashboardPage();
          case AuthStatus.unknown:
          case AuthStatus.loading:
            return const SplashPage();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginPage();
        }
      },
    );
  }
}
