import 'package:equatable/equatable.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {
  const ScannerInitial();
}

class ScannerScanning extends ScannerState {
  const ScannerScanning({required this.torchOn});

  final bool torchOn;

  @override
  List<Object?> get props => [torchOn];
}

class ScannerDetected extends ScannerState {
  const ScannerDetected(this.rawValue);

  final String rawValue;

  @override
  List<Object?> get props => [rawValue];
}

class ScannerError extends ScannerState {
  const ScannerError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
