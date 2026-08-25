import '../entities/cvl_search_result.dart';
import '../repositories/cvl_repository.dart';

class SearchCvlByName {
  SearchCvlByName(this._repository);

  final CvlRepository _repository;

  Future<List<CvlSearchResult>> call(String name) => _repository.searchByName(name);
}
