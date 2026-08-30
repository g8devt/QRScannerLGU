import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../app_update/domain/entities/app_version_check_result.dart';
import '../../../app_update/domain/usecases/check_app_update.dart';
import '../../../app_update/presentation/widgets/app_update_gate.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../splash/presentation/pages/splash_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';

/// Shown as the app's `home`. Dispatches [AppStarted] once, then swaps
/// between [LoginPage] and [DashboardPage] based on auth status.
///
/// On Android, also runs a mandatory version check in parallel: while the
/// check is unresolved or reports an outdated build, login/dashboard stay
/// unreachable and a non-dismissible update/retry dialog is shown instead
/// (see [AppUpdateGate]). The check re-runs whenever the app resumes, so
/// installing the update and returning to this (old) process still gets
/// re-verified rather than trusting the stale in-memory result.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.checkAppUpdate});

  final CheckAppUpdate checkAppUpdate;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  static const _splashDuration = Duration(seconds: 3);

  bool _splashDone = false;
  AppVersionCheckResult? _versionResult;
  bool _checkingVersion = false;

  bool get _requiresVersionCheck => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AuthBloc>().add(const AppStarted());
    Future.delayed(_splashDuration, () {
      if (mounted) setState(() => _splashDone = true);
    });
    _runVersionCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final blocked = _versionResult?.blocksLogin ?? false;
    if (state == AppLifecycleState.resumed && blocked) {
      _runVersionCheck();
    }
  }

  Future<void> _runVersionCheck() async {
    if (!_requiresVersionCheck) {
      setState(
        () => _versionResult = const AppVersionCheckResult(outcome: AppVersionCheckOutcome.upToDate),
      );
      return;
    }
    if (_checkingVersion) return;
    _checkingVersion = true;

    if (AppConfig.appVersion.isEmpty) {
      await AppConfig.initPackageInfo();
    }
    final result = await widget.checkAppUpdate(
      osType: 'ANDROID',
      currentVersion: AppConfig.appVersion,
    );

    _checkingVersion = false;
    if (mounted) setState(() => _versionResult = result);
  }

  Future<void> _openUpdateUrl() async {
    final url = _versionResult?.url;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Dialog stays up either way; the user can tap Update again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionResult = _versionResult;

    // Still splashing, or (on Android) still waiting on the first version
    // check result — never fall through to login while unverified.
    if (!_splashDone || versionResult == null) {
      return const SplashPage();
    }

    if (versionResult.blocksLogin) {
      return AppUpdateGate(
        result: versionResult,
        background: const SplashPage(),
        onUpdate: _openUpdateUrl,
        onRetry: _runVersionCheck,
      );
    }

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
