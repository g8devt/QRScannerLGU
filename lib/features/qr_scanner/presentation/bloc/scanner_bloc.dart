import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../domain/repositories/scanner_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc(this._repository) : super(const ScannerInitial()) {
    on<StartScan>(_onStartScan);
    on<CodeDetected>(
      _onCodeDetected,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<ToggleTorch>(_onToggleTorch);
    on<RetryScan>(_onStartScan);
    on<PauseScan>(_onPauseScan);
    on<ScanStreamError>(_onScanStreamError);
  }

  final ScannerRepository _repository;
  StreamSubscription<String>? _subscription;

  // StartScan/RetryScan and PauseScan are registered as separate `on<>`
  // handlers, so flutter_bloc processes them concurrently by default — a
  // PauseScan fired mid-flight (e.g. AppLifecycleState.paused while the OS
  // camera-permission dialog has focus) can interleave with the StartScan
  // that's still awaiting that same dialog's result, racing on the shared
  // `controller`/`_subscription`. That produced a ScannerError that got
  // immediately overwritten by the other handler's ScannerScanning emit —
  // the error card flashing and vanishing on a fresh install. This chain
  // serializes every call through _runExclusive so only one of
  // start/pause ever touches the controller at a time.
  Future<void> _exclusive = Future<void>.value();

  Future<void> _runExclusive(Future<void> Function() action) {
    final previous = _exclusive;
    final result = previous.then((_) => action());
    // Swallow errors here so one failed run doesn't break the chain for
    // subsequent calls; callers still see their own action's error.
    _exclusive = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _onStartScan(
    ScannerEvent event,
    Emitter<ScannerState> emit,
  ) => _runExclusive(() async {
    try {
      await _subscription?.cancel();
      await _repository.start();
      _subscription = _repository.detections.listen(
        (rawValue) => add(CodeDetected(rawValue)),
        onError: (Object error) => add(ScanStreamError(error.toString())),
      );
      emit(ScannerScanning(torchOn: _repository.isTorchOn));
    } catch (e) {
      if (e is MobileScannerException &&
          e.errorCode == MobileScannerErrorCode.permissionDenied) {
        emit(
          const ScannerError(
            'Camera permission is required. Please enable it in your device settings and tap Retry.',
          ),
        );
      } else {
        emit(ScannerError('Could not start the camera: $e'));
      }
    }
  });

  Future<void> _onPauseScan(
    ScannerEvent event,
    Emitter<ScannerState> emit,
  ) => _runExclusive(() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _repository.stop();
      emit(const ScannerInitial());
    } catch (e) {
      emit(ScannerError('Could not pause the camera: $e'));
    }
  });

  Future<void> _onScanStreamError(
    ScanStreamError event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerError('Scanner error: ${event.message}'));
  }

  Future<void> _onCodeDetected(
    CodeDetected event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is! ScannerScanning) return;
    try {
      await _subscription?.cancel();
      await _repository.stop();
      emit(ScannerDetected(event.rawValue));
    } catch (e) {
      emit(ScannerError('Could not stop the camera: $e'));
    }
  }

  Future<void> _onToggleTorch(
    ToggleTorch event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is! ScannerScanning) return;
    try {
      await _repository.toggleTorch();
      emit(ScannerScanning(torchOn: _repository.isTorchOn));
    } catch (e) {
      emit(ScannerError('Could not toggle torch: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _repository.dispose();
    return super.close();
  }
}
