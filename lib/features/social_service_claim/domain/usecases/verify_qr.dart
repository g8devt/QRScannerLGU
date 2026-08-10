import '../entities/verified_application.dart';
import '../repositories/claim_repository.dart';

class VerifyQr {
  VerifyQr(this._repository);

  final ClaimRepository _repository;

  Future<VerifiedApplication> call(String qrCode) => _repository.verifyQr(qrCode);
}
