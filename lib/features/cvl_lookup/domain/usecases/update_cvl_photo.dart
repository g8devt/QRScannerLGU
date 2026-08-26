import '../repositories/cvl_repository.dart';

class UpdateCvlPhoto {
  UpdateCvlPhoto(this._repository);

  final CvlRepository _repository;

  Future<String> call({
    required int id,
    required String photoPath,
    String? updatedBy,
  }) => _repository.updatePhoto(
    id: id,
    photoPath: photoPath,
    updatedBy: updatedBy,
  );
}
