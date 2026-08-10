import '../../../../core/network/api_client.dart';
import '../../domain/entities/claim_captures.dart';
import '../../domain/entities/claimant_info.dart';
import '../../domain/entities/verified_application.dart';
import '../../domain/repositories/claim_repository.dart';
import '../datasources/claim_remote_datasource.dart';

class ClaimRepositoryImpl implements ClaimRepository {
  ClaimRepositoryImpl(this._datasource);

  final ClaimRemoteDatasource _datasource;

  @override
  Future<VerifiedApplication> verifyQr(String qrCode) async {
    try {
      final json = await _datasource.verifyQr(qrCode);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return VerifiedApplication.fromJson(data);
    } on ApiException catch (e) {
      throw ClaimVerifyException(e.message);
    } catch (e) {
      throw ClaimVerifyException('Could not verify QR code: $e');
    }
  }

  @override
  Future<void> submitClaim({
    required int applicationId,
    required ClaimantInfo claimant,
    required ClaimCaptures captures,
  }) async {
    if (!captures.isComplete) {
      throw ClaimSubmitException('All 4 captures are required before submitting.');
    }
    try {
      await _datasource.submitClaim(
        applicationId: applicationId,
        claimantType: claimant.type == ClaimantType.self ? 'SELF' : 'REPRESENTATIVE',
        claimantName: claimant.name,
        claimantRelation: claimant.relation,
        claimantIdType: claimant.idType,
        claimantIdNumber: claimant.idNumber,
        idFrontPath: captures.idFrontPath!,
        idBackPath: captures.idBackPath!,
        signaturePath: captures.signaturePath!,
        facePhotoPath: captures.facePhotoPath!,
      );
    } on ApiException catch (e) {
      throw ClaimSubmitException(e.message);
    } catch (e) {
      throw ClaimSubmitException('Could not submit claim: $e');
    }
  }
}
