import 'package:image_picker/image_picker.dart';

/// Thin wrapper around [ImagePicker] — the only place in this feature that
/// talks to the `image_picker` plugin directly.
class ImagePickerDatasource {
  ImagePickerDatasource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Opens the device camera for a single photo. Returns the local file
  /// path, or `null` if the user cancelled.
  Future<String?> pickFromCamera() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera);
    return file?.path;
  }
}
