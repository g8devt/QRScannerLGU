import '../../../../core/network/api_client.dart';

/// Talks to `find_cvl_by_qr_bataan`. Returns raw decoded JSON — mapping
/// to the domain entity happens in [CvlRepositoryImpl].
class CvlRemoteDatasource {
  CvlRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> findByQr(String qrCode) {
    return _apiClient.post('find_cvl_by_qr_bataan', {'qr_code': qrCode});
  }
}
