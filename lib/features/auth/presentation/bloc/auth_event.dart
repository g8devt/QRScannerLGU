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
  const LoginRequested({required this.username, required this.password});

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

/// Staff tapped the logout control.
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
