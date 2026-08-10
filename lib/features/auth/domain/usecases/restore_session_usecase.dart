import '../entities/scanner_user.dart';
import '../repositories/auth_repository.dart';

class RestoreSessionUsecase {
  RestoreSessionUsecase(this._repository);

  final AuthRepository _repository;

  Future<ScannerUser?> call() => _repository.restoreSession();
}
