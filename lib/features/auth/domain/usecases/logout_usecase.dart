import '../repositories/auth_repository.dart';

class LogoutUsecase {
  LogoutUsecase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
