import '../repositories/cvl_repository.dart';

class SetCvlQr {
  SetCvlQr(this._repository);

  final CvlRepository _repository;

  Future<String> call({required int id, required String qrCode}) =>
      _repository.setQr(id: id, qrCode: qrCode);
}
