import '../repositories/cvl_repository.dart';

class UpdateCvlInfo {
  UpdateCvlInfo(this._repository);

  final CvlRepository _repository;

  Future<(String, String, String)> call({
    required int id,
    String? contactNo,
    String? email,
    String? gender,
    String? updatedBy,
  }) => _repository.updateInfo(
    id: id,
    contactNo: contactNo,
    email: email,
    gender: gender,
    updatedBy: updatedBy,
  );
}
