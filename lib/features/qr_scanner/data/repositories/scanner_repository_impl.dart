import '../../domain/repositories/scanner_repository.dart';
import '../datasources/mobile_scanner_datasource.dart';

class ScannerRepositoryImpl implements ScannerRepository {
  ScannerRepositoryImpl(this._datasource);

  final MobileScannerDatasource _datasource;

  @override
  Stream<String> get detections => _datasource.detections;

  @override
  bool get isTorchOn => _datasource.isTorchOn;

  @override
  Future<void> start() => _datasource.start();

  @override
  Future<void> stop() => _datasource.stop();

  @override
  Future<void> toggleTorch() => _datasource.toggleTorch();

  @override
  Future<void> dispose() => _datasource.dispose();
}
