import '../entities/claim_captures.dart';
import '../entities/claimant_info.dart';
import '../repositories/claim_repository.dart';

class SubmitClaim {
  SubmitClaim(this._repository);

  final ClaimRepository _repository;

  Future<void> call({
    required int applicationId,
    required ClaimantInfo claimant,
    required ClaimCaptures captures,
  }) {
    return _repository.submitClaim(applicationId: applicationId, claimant: claimant, captures: captures);
  }
}
