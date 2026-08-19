import '../entities/social_service_details.dart';
import '../repositories/claim_repository.dart';

class GetServiceDetails {
  GetServiceDetails(this._repository);

  final ClaimRepository _repository;

  Future<SocialServiceDetails> call(String qrCode) => _repository.getServiceDetails(qrCode);
}
