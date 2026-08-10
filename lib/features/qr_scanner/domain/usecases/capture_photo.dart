import '../repositories/camera_repository.dart';

/// Captures a single photo via [CameraRepository] and returns its local
/// path, or `null` if the user cancelled the capture.
class CapturePhoto {
  CapturePhoto(this.repository);

  final CameraRepository repository;

  Future<String?> call() => repository.capturePhoto();
}
