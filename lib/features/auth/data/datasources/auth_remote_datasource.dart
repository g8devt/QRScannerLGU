import '../../../../core/network/api_client.dart';

/// Talks to the scanner-staff login endpoint. Returns raw decoded JSON —
/// mapping to [ScannerUser] happens in AuthRepositoryImpl.
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login({required String username, required String password}) {
    return _apiClient.post('login_scanner_bataan', {'username': username, 'password': password});
  }
}
