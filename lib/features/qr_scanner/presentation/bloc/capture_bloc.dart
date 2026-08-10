import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/capture_photo.dart';
import 'capture_event.dart';
import 'capture_state.dart';

class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  CaptureBloc(this._capturePhoto) : super(const CaptureInitial()) {
    on<RequestCapture>(_onRequestCapture);
  }

  final CapturePhoto _capturePhoto;

  Future<void> _onRequestCapture(RequestCapture event, Emitter<CaptureState> emit) async {
    emit(const CaptureInProgress());
    try {
      final path = await _capturePhoto();
      if (path == null) {
        // User cancelled — silently return to the pre-capture state.
        emit(const CaptureInitial());
      } else {
        emit(CaptureSuccess(path));
      }
    } catch (e) {
      emit(CaptureFailure('Could not capture photo: $e'));
    }
  }
}
