import '../../data/datasources/app_update_remote_datasource.dart';
import '../entities/app_version_check_result.dart';

class CheckAppUpdate {
  CheckAppUpdate(this._datasource);

  final AppUpdateRemoteDatasource _datasource;

  Future<AppVersionCheckResult> call({
    required String osType,
    required String currentVersion,
  }) {
    return _datasource.checkVersion(osType: osType, currentVersion: currentVersion);
  }
}
