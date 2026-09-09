import 'package:mobile_scanner/mobile_scanner.dart';

/// Thin wrapper around [MobileScannerController] — the only place in this
/// feature that talks to the `mobile_scanner` plugin directly.
class MobileScannerDatasource {
  MobileScannerDatasource()
    : controller = MobileScannerController(
        autoStart: false,
        // App only ever issues QR codes (CVL records, social service
        // applications). Without this, mobile_scanner also detects 1D
        // barcodes, PDF417, etc., so pointing the camera at any barcode
        // gets treated as a hit even though nothing in this app is a
        // barcode.
        formats: const [BarcodeFormat.qrCode],
      );

  final MobileScannerController controller;

  bool get isTorchOn => controller.value.torchState == TorchState.on;

  /// Emits the raw value of each barcode detected while scanning.
  Stream<String> get detections {
    return controller.barcodes
        .map((capture) => capture.barcodes)
        .expand((barcodes) => barcodes)
        .map((barcode) => barcode.rawValue)
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>();
  }

  Future<void> start() => controller.start();

  Future<void> stop() => controller.stop();

  Future<void> toggleTorch() => controller.toggleTorch();

  Future<void> dispose() => controller.dispose();
}
