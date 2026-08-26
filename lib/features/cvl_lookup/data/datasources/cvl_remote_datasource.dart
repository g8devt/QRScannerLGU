import '../../../../core/network/api_client.dart';

/// Talks to `find_cvl_by_qr_bataan` / `get_cvl_by_id_bataan` /
/// `search_cvl_by_name_bataan` / `update_cvl_photo_bataan` /
/// `set_cvl_qr_bataan` / `remove_cvl_qr_bataan`. Returns raw decoded
/// JSON — mapping to domain entities happens in [CvlRepositoryImpl].
class CvlRemoteDatasource {
  CvlRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> findByQr(String qrCode) {
    return _apiClient.post('find_cvl_by_qr_bataan', {'qr_code': qrCode});
  }

  Future<Map<String, dynamic>> findById(int id) {
    return _apiClient.post('get_cvl_by_id_bataan', {'id': id.toString()});
  }

  Future<Map<String, dynamic>> searchByName(String name, {int offset = 0}) {
    return _apiClient.post('search_cvl_by_name_bataan', {
      'name': name,
      'offset': offset.toString(),
    });
  }

  /// Assigns [qrCode] to CVL record [id]. The server validates the code
  /// against `app_qr_code` — unregistered or already-used codes come back
  /// as a rejected [ApiException] via [ApiClient._decode], not a thrown
  /// error here.
  Future<Map<String, dynamic>> setQr({
    required int id,
    required String qrCode,
  }) {
    return _apiClient.post('set_cvl_qr_bataan', {
      'id': id.toString(),
      'qr_code': qrCode,
    });
  }

  /// Unassigns whatever QR code is currently set on CVL record [id],
  /// freeing it in `app_qr_code` for reuse. The backend rejects a record
  /// that has no QR assigned as a [ApiException] via [ApiClient._decode].
  Future<Map<String, dynamic>> removeQr({required int id}) {
    return _apiClient.post('remove_cvl_qr_bataan', {'id': id.toString()});
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
