import 'package:equatable/equatable.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

/// Starts (or resumes) the camera and scanning.
class StartScan extends ScannerEvent {
  const StartScan();
}

/// Fired internally when the repository's detection stream emits a code.
class CodeDetected extends ScannerEvent {
  const CodeDetected(this.rawValue);

  final String rawValue;

  @override
  List<Object?> get props => [rawValue];
}

/// Toggles the torch/flash.
class ToggleTorch extends ScannerEvent {
  const ToggleTorch();
}

/// Retries starting the scanner after an error.
class RetryScan extends ScannerEvent {
  const RetryScan();
}

/// Pauses scanning (e.g. when the app is backgrounded) and stops the camera.
class PauseScan extends ScannerEvent {
  const PauseScan();
}

/// Fired internally when the repository's detection stream emits an error.
class ScanStreamError extends ScannerEvent {
  const ScanStreamError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
