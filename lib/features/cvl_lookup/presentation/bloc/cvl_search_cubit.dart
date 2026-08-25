import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/search_cvl_by_name.dart';
import 'cvl_search_state.dart';

/// Backend caps `search_cvl_by_name_bataan` at 25 results — matched here
/// only to detect truncation for the UI hint, not to enforce the cap
/// client-side.
const _resultCap = 25;

class CvlSearchCubit extends Cubit<CvlSearchState> {
  CvlSearchCubit(this._searchCvlByName) : super(const CvlSearchState());

  final SearchCvlByName _searchCvlByName;

  /// Searches by [name]. No-ops (clears results) for names shorter than
  /// 2 characters, matching the backend's minimum — avoids a request the
  /// server would just reject.
  Future<void> search(String name) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      emit(const CvlSearchState());
      return;
    }

    emit(state.copyWith(status: CvlSearchStatus.loading));
    try {
      final results = await _searchCvlByName(trimmed);
      emit(state.copyWith(
        status: CvlSearchStatus.loaded,
        results: results,
        truncated: results.length >= _resultCap,
      ));
    } catch (e) {
      emit(state.copyWith(status: CvlSearchStatus.failed, errorMessage: e.toString(), results: const []));
    }
  }

  void reset() => emit(const CvlSearchState());
}
