import 'package:equatable/equatable.dart';

abstract class CaptureEvent extends Equatable {
  const CaptureEvent();

  @override
  List<Object?> get props => [];
}

/// Requests opening the camera to capture a verification photo.
class RequestCapture extends CaptureEvent {
  const RequestCapture();
}
