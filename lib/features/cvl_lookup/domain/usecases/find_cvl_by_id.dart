import '../entities/cvl_record.dart';
import '../repositories/cvl_repository.dart';

class FindCvlById {
  FindCvlById(this._repository);

  final CvlRepository _repository;

  Future<CvlRecord> call(int id) => _repository.findById(id);
}
