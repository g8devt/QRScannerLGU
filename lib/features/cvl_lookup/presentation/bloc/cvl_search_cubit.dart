import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_search_filters.dart';
import '../../domain/usecases/get_cvl_filter_options.dart';
import '../../domain/usecases/remove_cvl_qr.dart';
import '../../domain/usecases/search_cvl_by_name.dart';
import '../../domain/usecases/set_cvl_qr.dart';
import 'cvl_search_state.dart';

class CvlSearchCubit extends Cubit<CvlSearchState> {
  CvlSearchCubit(
    this._searchCvlByName,
    this._setCvlQr,
    this._removeCvlQr,
    this._getCvlFilterOptions,
  ) : super(const CvlSearchState());

  final SearchCvlByName _searchCvlByName;
  final SetCvlQr _setCvlQr;
  final RemoveCvlQr _removeCvlQr;
  final GetCvlFilterOptions _getCvlFilterOptions;

  // Tracks the in-flight/last search term so loadMore() and applyFilters()
  // (triggered without a term of their own) know what to page through /
  // re-search with.
  String _term = '';

  /// Searches by [name]. With no filters applied, no-ops (clears results)
  /// for names shorter than 2 characters, matching the backend's minimum
  /// — avoids a request the server would just reject. A non-empty
  /// [state.filters] relaxes that: an empty or short term still searches,
  /// browsing purely by filter. Always starts from the first page.
  Future<void> search(String name) async {
    final trimmed = name.trim();
    _term = trimmed;
    if (trimmed.length < 2 && state.filters.isEmpty) {
      emit(state.copyWith(status: CvlSearchStatus.initial, results: const []));
      return;
    }

    emit(state.copyWith(status: CvlSearchStatus.loading));
    try {
      final page = await _searchCvlByName(trimmed, filters: state.filters);
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
      final page = await _searchCvlByName(
        _term,
        offset: state.results.length,
        filters: state.filters,
      );
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

  /// Applies [filters] and re-runs the search from the first page. Passed
  /// through to [search], so the same empty-term/no-filters no-op rule
  /// applies.
  Future<void> applyFilters(CvlSearchFilters filters) async {
    emit(state.copyWith(filters: filters));
    await search(_term);
  }

  /// Loads the filter sheet's dropdown choices, once, the first time it's
  /// opened. A no-op on repeat calls once loaded or already in flight.
  Future<void> loadFilterOptions() async {
    if (state.filterOptionsStatus == CvlFilterOptionsStatus.loading ||
        state.filterOptionsStatus == CvlFilterOptionsStatus.loaded) {
      return;
    }

    emit(state.copyWith(filterOptionsStatus: CvlFilterOptionsStatus.loading));
    try {
      final options = await _getCvlFilterOptions();
      emit(
        state.copyWith(
          filterOptions: options,
          filterOptionsStatus: CvlFilterOptionsStatus.loaded,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(filterOptionsStatus: CvlFilterOptionsStatus.failed),
      );
    }
  }

  /// Assigns [qrCode] (freshly scanned) to CVL record [id]. On success,
  /// updates that record in [CvlSearchState.results] in place so the list
  /// reflects it immediately. Rethrows [CvlLookupException] on rejection
  /// (unregistered/already-used code) or network failure — the caller
  /// (the scanning sheet) is responsible for showing that error, since a
  /// rejection shouldn't disturb the rest of the list.
  Future<void> setQr({required int id, required String qrCode}) async {
    final assigned = await _setCvlQr(id: id, qrCode: qrCode);
    emit(
      state.copyWith(
        results: [
          for (final result in state.results)
            if (result.id == id) result.copyWith(qrCode: assigned) else result,
        ],
      ),
    );
  }

  /// Unassigns the QR code from CVL record [id]. On success, updates
  /// that record in [CvlSearchState.results] in place so the list
  /// reflects it immediately. Rethrows [CvlLookupException] on rejection
  /// (no QR assigned) or network failure — the caller is responsible for
  /// showing that error.
  Future<void> removeQr(int id) async {
    await _removeCvlQr(id: id);
    emit(
      state.copyWith(
        results: [
          for (final result in state.results)
            if (result.id == id) result.copyWith(qrCode: '') else result,
        ],
      ),
    );
  }

  void reset() => emit(const CvlSearchState());
}
