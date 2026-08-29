import '../entities/cvl_search_filters.dart';
import '../repositories/cvl_repository.dart';

class GetCvlFilterOptions {
  GetCvlFilterOptions(this._repository);

  final CvlRepository _repository;

  Future<CvlFilterOptions> call() => _repository.getFilterOptions();
}
