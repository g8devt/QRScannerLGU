import 'package:equatable/equatable.dart';

import 'cvl_search_result.dart';

/// One page of `search_cvl_by_name_bataan` results, as returned by
/// [CvlRepository.searchByName].
class CvlSearchResultsPage extends Equatable {
  const CvlSearchResultsPage({required this.results, required this.hasMore});

  final List<CvlSearchResult> results;

  /// True when another page of matches exists beyond this one.
  final bool hasMore;

  @override
  List<Object?> get props => [results, hasMore];
}
