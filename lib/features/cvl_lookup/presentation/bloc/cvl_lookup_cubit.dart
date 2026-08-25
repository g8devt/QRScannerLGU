import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/find_cvl_by_qr.dart';
import '../../domain/usecases/update_cvl_photo.dart';
import 'cvl_lookup_state.dart';

class CvlLookupCubit extends Cubit<CvlLookupState> {
  CvlLookupCubit(this._findCvlByQr, this._updateCvlPhoto) : super(const CvlLookupState());

  final FindCvlByQr _findCvlByQr;
  final UpdateCvlPhoto _updateCvlPhoto;

  Future<void> fetch(String qrCode) async {
    emit(state.copyWith(status: CvlLookupStatus.loading));
    try {
      final record = await _findCvlByQr(qrCode);
      emit(state.copyWith(status: CvlLookupStatus.loaded, record: record));
    } catch (e) {
      emit(state.copyWith(status: CvlLookupStatus.failed, errorMessage: e.toString()));
    }
  }

  /// Uploads [photoPath] as the loaded record's new photo. No-ops if no
  /// record is currently loaded. On success, updates the displayed record
  /// in place — no re-fetch needed.
  Future<void> updatePhoto(String photoPath, {String? updatedBy}) async {
    final current = state.record;
    if (current == null) return;

    emit(state.copyWith(isUpdatingPhoto: true, photoUpdateError: null));
    try {
      final newUrl = await _updateCvlPhoto(id: current.id, photoPath: photoPath, updatedBy: updatedBy);
      emit(state.copyWith(record: current.copyWith(imgPath: newUrl), isUpdatingPhoto: false));
    } catch (e) {
      emit(state.copyWith(isUpdatingPhoto: false, photoUpdateError: e.toString()));
    }
  }

  void reset() => emit(const CvlLookupState());
}
