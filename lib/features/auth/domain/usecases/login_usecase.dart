import '../entities/scanner_user.dart';
import '../repositories/auth_repository.dart';

class LoginUsecase {
  LoginUsecase(this._repository);

  final AuthRepository _repository;

  Future<ScannerUser> call({required String username, required String password}) =>
      _repository.login(username: username, password: password);
}
