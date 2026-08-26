import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_search_result.dart';

enum CvlSearchStatus { initial, loading, loaded, failed }

class CvlSearchState extends Equatable {
  const CvlSearchState({
    this.status = CvlSearchStatus.initial,
    this.results = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final CvlSearchStatus status;
  final List<CvlSearchResult> results;

  /// True when another page of matches exists beyond [results] — the
  /// page uses this to trigger loading the next page as the staff member
  /// scrolls near the bottom of the list.
  final bool hasMore;

  /// True while a next-page fetch (triggered by scrolling) is in flight,
  /// distinct from [CvlSearchStatus.loading] which covers the initial
  /// search — keeps the existing results on screen with a trailing
  /// spinner instead of replacing them with a full-page loading state.
  final bool isLoadingMore;

  final String? errorMessage;

  CvlSearchState copyWith({
    CvlSearchStatus? status,
    List<CvlSearchResult>? results,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return CvlSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    results,
    hasMore,
    isLoadingMore,
    errorMessage,
  ];
}
