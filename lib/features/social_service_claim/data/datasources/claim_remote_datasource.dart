import '../../../../core/network/api_client.dart';

/// Talks to the two Bataan-specific claim endpoints. Returns raw decoded
/// JSON — mapping to domain entities happens in [ClaimRepositoryImpl].
class ClaimRemoteDatasource {
  ClaimRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> verifyQr(String qrCode) {
    return _apiClient.post('verify_qr_bataan', {'qr_code': qrCode});
  }

  Future<void> submitClaim({
    required int applicationId,
    required String claimantType,
    required String claimantName,
    required String claimantRelation,
    required String claimantIdType,
    required String claimantIdNumber,
    required String idFrontPath,
    String? idBackPath,
    required String signaturePath,
    required String facePhotoPath,
  }) {
    return _apiClient.postMultipart(
      'submit_claim_bataan',
      {
        'id': applicationId.toString(),
        'claim_method': 'QR',
        'claimant_type': claimantType,
        'claimant_name': claimantName,
        'claimant_relation': claimantRelation,
        'claimant_id_type': claimantIdType,
        'claimant_id_number': claimantIdNumber,
      },
      {
        'claimant_id_front': idFrontPath,
        // ignore: use_null_aware_elements
        if (idBackPath != null) 'claimant_id_back': idBackPath,
        'claimant_signature': signaturePath,
        'claimant_face_photo': facePhotoPath,
      },
    );
  }
}
