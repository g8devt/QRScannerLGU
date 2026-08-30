import '../../../../core/network/api_client.dart';
import '../../domain/entities/app_version_check_result.dart';

/// Talks to `check_app_version_scanner_bataan`. Any request failure
/// (network, server, unexpected payload) resolves to [checkFailed] rather
/// than throwing, so callers never have to guess between "up to date" and
/// "couldn't verify".
class AppUpdateRemoteDatasource {
  AppUpdateRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<AppVersionCheckResult> checkVersion({
    required String osType,
    required String currentVersion,
  }) async {
    try {
      final response = await _apiClient.post('check_app_version_scanner_bataan', {
        'os_type': osType,
        'current_version': currentVersion,
      });

      if (response['update_required'] != true) {
        return const AppVersionCheckResult(outcome: AppVersionCheckOutcome.upToDate);
      }

      return AppVersionCheckResult(
        outcome: AppVersionCheckOutcome.updateRequired,
        latestVersion: response['latest_version']?.toString(),
        url: response['url']?.toString(),
      );
    } catch (_) {
      return const AppVersionCheckResult(outcome: AppVersionCheckOutcome.checkFailed);
    }
  }
}
