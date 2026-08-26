import '../entities/cvl_search_results_page.dart';
import '../repositories/cvl_repository.dart';

class SearchCvlByName {
  SearchCvlByName(this._repository);

  final CvlRepository _repository;

  Future<CvlSearchResultsPage> call(String name, {int offset = 0}) =>
      _repository.searchByName(name, offset: offset);
}
