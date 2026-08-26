import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/find_cvl_by_id.dart';
import '../../domain/usecases/find_cvl_by_qr.dart';
import '../../domain/usecases/update_cvl_info.dart';
import '../../domain/usecases/update_cvl_photo.dart';
import 'cvl_lookup_state.dart';

class CvlLookupCubit extends Cubit<CvlLookupState> {
  CvlLookupCubit(
    this._findCvlByQr,
    this._updateCvlPhoto,
    this._findCvlById,
    this._updateCvlInfo,
  ) : super(const CvlLookupState());

  final FindCvlByQr _findCvlByQr;
  final UpdateCvlPhoto _updateCvlPhoto;
  final FindCvlById _findCvlById;
  final UpdateCvlInfo _updateCvlInfo;

  Future<void> fetch(String qrCode) async {
    emit(state.copyWith(status: CvlLookupStatus.loading));
    try {
      final record = await _findCvlByQr(qrCode);
      emit(state.copyWith(status: CvlLookupStatus.loaded, record: record));
    } catch (e) {
      emit(
        state.copyWith(
          status: CvlLookupStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Same as [fetch], but for the search flow — loads by `app_cvl_list.id`
  /// instead of a scanned QR value.
  Future<void> fetchById(int id) async {
    emit(state.copyWith(status: CvlLookupStatus.loading));
    try {
      final record = await _findCvlById(id);
      emit(state.copyWith(status: CvlLookupStatus.loaded, record: record));
    } catch (e) {
      emit(
        state.copyWith(
          status: CvlLookupStatus.failed,
          errorMessage: e.toString(),
        ),
      );
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
      final newUrl = await _updateCvlPhoto(
        id: current.id,
        photoPath: photoPath,
        updatedBy: updatedBy,
      );
      emit(
        state.copyWith(
          record: current.copyWith(imgPath: newUrl),
          isUpdatingPhoto: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(isUpdatingPhoto: false, photoUpdateError: e.toString()),
      );
    }
  }

  /// Saves an edit to the loaded record's contact number, email, and/or
  /// gender — whichever of [contactNo]/[email]/[gender] is non-null. At
  /// least one must be provided. No-ops if no record is currently
  /// loaded. On success, updates the displayed record in place — no
  /// re-fetch needed.
  Future<void> updateInfo({
    String? contactNo,
    String? email,
    String? gender,
    String? updatedBy,
  }) async {
    final current = state.record;
    if (current == null) return;

    emit(state.copyWith(isUpdatingInfo: true, infoUpdateError: null));
    try {
      final (
        newContactNo,
        newEmail,
        newGender,
      ) = await _updateCvlInfo(
        id: current.id,
        contactNo: contactNo,
        email: email,
        gender: gender,
        updatedBy: updatedBy,
      );
      emit(
        state.copyWith(
          record: current.copyWith(
            contactNo: newContactNo,
            email: newEmail,
            gender: newGender,
          ),
          isUpdatingInfo: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(isUpdatingInfo: false, infoUpdateError: e.toString()),
      );
    }
  }

  void reset() => emit(const CvlLookupState());
}
