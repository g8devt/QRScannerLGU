/// Abstraction over a QR/barcode scanning source. Implemented in the data
/// layer; domain and presentation only ever see this interface.
abstract class ScannerRepository {
  /// Emits the raw string value of each detected code while scanning is
  /// active.
  Stream<String> get detections;

  /// Whether the torch is currently on.
  bool get isTorchOn;

  /// Starts (or resumes) the camera and detection stream.
  Future<void> start();

  /// Stops the camera and detection stream.
  Future<void> stop();

  /// Toggles the torch/flash. Throws if the device has no torch.
  Future<void> toggleTorch();

  /// Releases underlying camera resources. Call when the repository is no
  /// longer needed.
  Future<void> dispose();
}
