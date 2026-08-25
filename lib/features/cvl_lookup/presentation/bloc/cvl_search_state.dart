import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_search_result.dart';

enum CvlSearchStatus { initial, loading, loaded, failed }

class CvlSearchState extends Equatable {
  const CvlSearchState({
    this.status = CvlSearchStatus.initial,
    this.results = const [],
    this.truncated = false,
    this.errorMessage,
  });

  final CvlSearchStatus status;
  final List<CvlSearchResult> results;

  /// True when the backend capped the match count (more than 25 results
  /// exist) — the page uses this to hint "refine your search".
  final bool truncated;
  final String? errorMessage;

  CvlSearchState copyWith({
    CvlSearchStatus? status,
    List<CvlSearchResult>? results,
    bool? truncated,
    String? errorMessage,
  }) {
    return CvlSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      truncated: truncated ?? this.truncated,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, results, truncated, errorMessage];
}
