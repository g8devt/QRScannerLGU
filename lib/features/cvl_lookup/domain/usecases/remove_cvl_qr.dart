import '../repositories/cvl_repository.dart';

class RemoveCvlQr {
  RemoveCvlQr(this._repository);

  final CvlRepository _repository;

  Future<void> call({required int id}) => _repository.removeQr(id: id);
}
