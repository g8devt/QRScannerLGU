import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Checked once on app start — restores a cached session if one exists.
class AppStarted extends AuthEvent {
  const AppStarted();
}

/// Submits the login form.
class LoginRequested extends AuthEvent {
  const LoginRequested({
    required this.username,
    required this.password,
    this.rememberMe = true,
  });

  final String username;
  final String password;

  /// Whether the session should be persisted so the app auto-logs-in on
  /// the next launch. If false, the session only lasts for this run.
  final bool rememberMe;

  @override
  List<Object?> get props => [username, password, rememberMe];
}

/// Staff tapped the logout control.
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
