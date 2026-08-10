import 'package:equatable/equatable.dart';

abstract class CaptureState extends Equatable {
  const CaptureState();

  @override
  List<Object?> get props => [];
}

class CaptureInitial extends CaptureState {
  const CaptureInitial();
}

class CaptureInProgress extends CaptureState {
  const CaptureInProgress();
}

class CaptureSuccess extends CaptureState {
  const CaptureSuccess(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

class CaptureFailure extends CaptureState {
  const CaptureFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
