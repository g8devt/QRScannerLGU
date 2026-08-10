/// Abstraction over capturing a single photo with the device camera.
abstract class CameraRepository {
  /// Opens the camera for a single capture and returns the local file path
  /// of the resulting image, or `null` if the user cancelled.
  Future<String?> capturePhoto();
}
