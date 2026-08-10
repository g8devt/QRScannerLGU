import '../../domain/repositories/camera_repository.dart';
import '../datasources/image_picker_datasource.dart';

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl(this._datasource);

  final ImagePickerDatasource _datasource;

  @override
  Future<String?> capturePhoto() => _datasource.pickFromCamera();
}
