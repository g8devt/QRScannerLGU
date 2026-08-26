import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/search_cvl_by_name.dart';
import 'cvl_search_state.dart';

class CvlSearchCubit extends Cubit<CvlSearchState> {
  CvlSearchCubit(this._searchCvlByName) : super(const CvlSearchState());

  final SearchCvlByName _searchCvlByName;

  // Tracks the in-flight/last search term so loadMore() (triggered by
  // scrolling, with no term of its own) knows what to page through.
  String _term = '';

  /// Searches by [name]. No-ops (clears results) for names shorter than
  /// 2 characters, matching the backend's minimum — avoids a request the
  /// server would just reject. Always starts from the first page.
  Future<void> search(String name) async {
    final trimmed = name.trim();
    _term = trimmed;
    if (trimmed.length < 2) {
      emit(const CvlSearchState());
      return;
    }

    emit(state.copyWith(status: CvlSearchStatus.loading));
    try {
      final page = await _searchCvlByName(trimmed);
      emit(
        state.copyWith(
          status: CvlSearchStatus.loaded,
          results: page.results,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CvlSearchStatus.failed,
          errorMessage: e.toString(),
          results: const [],
        ),
      );
    }
  }

  /// Fetches the next page and appends it to the current results — called
  /// as the staff member scrolls near the bottom of the list. A no-op
  /// while the initial search or another loadMore is still in flight, or
  /// once the backend has reported no further pages.
  Future<void> loadMore() async {
    if (state.status != CvlSearchStatus.loaded ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _searchCvlByName(_term, offset: state.results.length);
      emit(
        state.copyWith(
          results: [...state.results, ...page.results],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      // Keep the results already on screen; just drop back to "has more"
      // so the staff member can retry by scrolling again.
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void reset() => emit(const CvlSearchState());
}
