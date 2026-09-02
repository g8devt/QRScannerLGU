import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_record.dart';

enum CvlLookupStatus {
  initial,
  loading,
  loaded,
  failed,

  /// Record found via a scanned QR, but its `cvl_status` isn't `ACTIVE` —
  /// scanning is blocked. [CvlLookupState.record] still holds the record
  /// (so the blocking dialog can reference its name/status), but no
  /// scan-related action proceeds.
  blocked,
}

class CvlLookupState extends Equatable {
  const CvlLookupState({
    this.status = CvlLookupStatus.initial,
    this.record,
    this.errorMessage,
    this.isUpdatingPhoto = false,
    this.photoUpdateError,
    this.isUpdatingInfo = false,
    this.infoUpdateError,
  });

  final CvlLookupStatus status;
  final CvlRecord? record;
  final String? errorMessage;

  /// True while a photo edit upload is in flight. Separate from [status]
  /// so an in-progress photo edit doesn't blank the already-loaded record
  /// behind a full-page spinner.
  final bool isUpdatingPhoto;

  /// Set when a photo edit fails; cleared on the next edit attempt.
  final String? photoUpdateError;

  /// True while a contact/email/gender edit save is in flight. Same
  /// reasoning as [isUpdatingPhoto].
  final bool isUpdatingInfo;

  /// Set when an info edit save fails; cleared on the next save attempt.
  final String? infoUpdateError;

  CvlLookupState copyWith({
    CvlLookupStatus? status,
    CvlRecord? record,
    String? errorMessage,
    bool? isUpdatingPhoto,
    String? photoUpdateError,
    bool? isUpdatingInfo,
    String? infoUpdateError,
  }) {
    return CvlLookupState(
      status: status ?? this.status,
      record: record ?? this.record,
      errorMessage: errorMessage,
      isUpdatingPhoto: isUpdatingPhoto ?? this.isUpdatingPhoto,
      photoUpdateError: photoUpdateError,
      isUpdatingInfo: isUpdatingInfo ?? this.isUpdatingInfo,
      infoUpdateError: infoUpdateError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    record,
    errorMessage,
    isUpdatingPhoto,
    photoUpdateError,
    isUpdatingInfo,
    infoUpdateError,
  ];
}
