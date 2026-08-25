import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/find_cvl_by_qr.dart';
import 'cvl_lookup_state.dart';

class CvlLookupCubit extends Cubit<CvlLookupState> {
  CvlLookupCubit(this._findCvlByQr) : super(const CvlLookupState());

  final FindCvlByQr _findCvlByQr;

  Future<void> fetch(String qrCode) async {
    emit(state.copyWith(status: CvlLookupStatus.loading));
    try {
      final record = await _findCvlByQr(qrCode);
      emit(state.copyWith(status: CvlLookupStatus.loaded, record: record));
    } catch (e) {
      emit(state.copyWith(status: CvlLookupStatus.failed, errorMessage: e.toString()));
    }
  }

  void reset() => emit(const CvlLookupState());
}
