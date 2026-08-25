import '../../../../core/network/api_client.dart';

/// Talks to `find_cvl_by_qr_bataan` / `get_cvl_by_id_bataan` /
/// `search_cvl_by_name_bataan` / `update_cvl_photo_bataan`. Returns raw
/// decoded JSON — mapping to domain entities happens in
/// [CvlRepositoryImpl].
class CvlRemoteDatasource {
  CvlRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> findByQr(String qrCode) {
    return _apiClient.post('find_cvl_by_qr_bataan', {'qr_code': qrCode});
  }

  Future<Map<String, dynamic>> findById(int id) {
    return _apiClient.post('get_cvl_by_id_bataan', {'id': id.toString()});
  }

  Future<Map<String, dynamic>> searchByName(String name) {
    return _apiClient.post('search_cvl_by_name_bataan', {'name': name});
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
