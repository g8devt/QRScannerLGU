import '../../../../core/network/api_client.dart';

/// Talks to `find_cvl_by_qr_bataan` / `update_cvl_photo_bataan`. Returns
/// raw decoded JSON — mapping to the domain entity happens in
/// [CvlRepositoryImpl].
class CvlRemoteDatasource {
  CvlRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> findByQr(String qrCode) {
    return _apiClient.post('find_cvl_by_qr_bataan', {'qr_code': qrCode});
  }

  Future<Map<String, dynamic>> updatePhoto({
    required int id,
    required String photoPath,
    String? updatedBy,
  }) {
    return _apiClient.postMultipart(
      'update_cvl_photo_bataan',
      {
        'id': id.toString(),
        // ignore: use_null_aware_elements
        if (updatedBy != null && updatedBy.isNotEmpty) 'updated_by': updatedBy,
      },
      {'cvl_photo': photoPath},
    );
  }
}
