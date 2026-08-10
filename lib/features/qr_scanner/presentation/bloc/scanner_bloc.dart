import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/scanner_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc(this._repository) : super(const ScannerInitial()) {
    on<StartScan>(_onStartScan);
    on<CodeDetected>(_onCodeDetected, transformer: (events, mapper) => events.asyncExpand(mapper));
    on<ToggleTorch>(_onToggleTorch);
    on<RetryScan>(_onStartScan);
  }

  final ScannerRepository _repository;
  StreamSubscription<String>? _subscription;

  Future<void> _onStartScan(ScannerEvent event, Emitter<ScannerState> emit) async {
    try {
      await _subscription?.cancel();
      await _repository.start();
      _subscription = _repository.detections.listen((rawValue) => add(CodeDetected(rawValue)));
      emit(ScannerScanning(torchOn: _repository.isTorchOn));
    } catch (e) {
      emit(ScannerError('Could not start the camera: $e'));
    }
  }

  Future<void> _onCodeDetected(CodeDetected event, Emitter<ScannerState> emit) async {
    if (state is! ScannerScanning) return;
    try {
      await _subscription?.cancel();
      await _repository.stop();
      emit(ScannerDetected(event.rawValue));
    } catch (e) {
      emit(ScannerError('Could not stop the camera: $e'));
    }
  }

  Future<void> _onToggleTorch(ToggleTorch event, Emitter<ScannerState> emit) async {
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
