import 'package:mobile_scanner/mobile_scanner.dart';

/// Thin wrapper around [MobileScannerController] — the only place in this
/// feature that talks to the `mobile_scanner` plugin directly.
class MobileScannerDatasource {
  MobileScannerDatasource() : controller = MobileScannerController();

  final MobileScannerController controller;

  bool get isTorchOn => controller.torchEnabled;

  /// Emits the raw value of each barcode detected while scanning.
  Stream<String> get detections {
    return controller.barcodes
        .map((capture) => capture.barcodes)
        .expand((barcodes) => barcodes)
        .map((barcode) => barcode.rawValue)
        .where((value) => value != null)
        .cast<String>();
  }

  Future<void> start() => controller.start();

  Future<void> stop() => controller.stop();

  Future<void> toggleTorch() => controller.toggleTorch();

  Future<void> dispose() => controller.dispose();
}
