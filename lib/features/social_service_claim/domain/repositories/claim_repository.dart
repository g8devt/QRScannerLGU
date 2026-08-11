import '../entities/claim_captures.dart';
import '../entities/claimant_info.dart';
import '../entities/verified_application.dart';

abstract class ClaimRepository {
  /// Looks up [qrCode] against the backend. Returns the verified
  /// application when eligible for claim. Throws [ClaimVerifyException]
  /// with a human-readable reason on any rejection (not found, already
  /// claimed, not yet eligible) or network failure.
  Future<VerifiedApplication> verifyQr(String qrCode);

  /// Submits the claim: claimant info + 4 capture file paths, plus which
  /// scanner-staff account processed it. Throws [ClaimSubmitException]
  /// with a human-readable reason on failure.
  Future<void> submitClaim({
    required int applicationId,
    required ClaimantInfo claimant,
    required ClaimCaptures captures,
    int? usersScannerId,
  });
}

class ClaimVerifyException implements Exception {
  ClaimVerifyException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ClaimSubmitException implements Exception {
  ClaimSubmitException(this.message);
  final String message;
  @override
  String toString() => message;
}
