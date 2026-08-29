import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_search_filters.dart';
import '../../domain/entities/cvl_search_result.dart';

enum CvlSearchStatus { initial, loading, loaded, failed }

/// Load state for [CvlSearchState.filterOptions], fetched lazily the first
/// time the filter sheet is opened.
enum CvlFilterOptionsStatus { notLoaded, loading, loaded, failed }

class CvlSearchState extends Equatable {
  const CvlSearchState({
    this.status = CvlSearchStatus.initial,
    this.results = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.filters = const CvlSearchFilters(),
    this.filterOptions = const CvlFilterOptions(),
    this.filterOptionsStatus = CvlFilterOptionsStatus.notLoaded,
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

  /// Currently applied filter selection.
  final CvlSearchFilters filters;

  /// Dropdown choices for the filter sheet, from `get_cvl_filter_options_bataan`.
  final CvlFilterOptions filterOptions;
  final CvlFilterOptionsStatus filterOptionsStatus;

  CvlSearchState copyWith({
    CvlSearchStatus? status,
    List<CvlSearchResult>? results,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    CvlSearchFilters? filters,
    CvlFilterOptions? filterOptions,
    CvlFilterOptionsStatus? filterOptionsStatus,
  }) {
    return CvlSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      filters: filters ?? this.filters,
      filterOptions: filterOptions ?? this.filterOptions,
      filterOptionsStatus: filterOptionsStatus ?? this.filterOptionsStatus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    results,
    hasMore,
    isLoadingMore,
    errorMessage,
    filters,
    filterOptions,
    filterOptionsStatus,
  ];
}
