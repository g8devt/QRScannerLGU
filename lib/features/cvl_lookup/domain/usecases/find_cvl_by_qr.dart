import '../entities/cvl_record.dart';
import '../repositories/cvl_repository.dart';

class FindCvlByQr {
  FindCvlByQr(this._repository);

  final CvlRepository _repository;

  Future<CvlRecord> call(String qrCode) => _repository.findByQr(qrCode);
}
