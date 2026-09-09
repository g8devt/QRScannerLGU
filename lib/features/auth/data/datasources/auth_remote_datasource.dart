import '../../../../core/network/api_client.dart';

/// Talks to the scanner-staff login/session endpoints. Returns raw
/// decoded JSON — mapping to [ScannerUser] or interpreting `is_valid`
/// happens in AuthRepositoryImpl.
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login({required String username, required String password}) {
    return _apiClient.post('login_scanner_bataan', {'username': username, 'password': password});
  }

  /// Revalidates an existing session's account against
  /// `check_scanner_status_bataan`. The response always carries
  /// `is_valid` on success (200) — a thrown [ApiException] here means the
  /// backend couldn't be reached/errored, not that the account is
  /// inactive.
  Future<Map<String, dynamic>> checkStatus({required int userId}) {
    return _apiClient.post('check_scanner_status_bataan', {'user_profile_id': userId.toString()});
  }
}
