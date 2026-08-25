import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_record.dart';

enum CvlLookupStatus { initial, loading, loaded, failed }

class CvlLookupState extends Equatable {
  const CvlLookupState({
    this.status = CvlLookupStatus.initial,
    this.record,
    this.errorMessage,
    this.isUpdatingPhoto = false,
    this.photoUpdateError,
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

  CvlLookupState copyWith({
    CvlLookupStatus? status,
    CvlRecord? record,
    String? errorMessage,
    bool? isUpdatingPhoto,
    String? photoUpdateError,
  }) {
    return CvlLookupState(
      status: status ?? this.status,
      record: record ?? this.record,
      errorMessage: errorMessage,
      isUpdatingPhoto: isUpdatingPhoto ?? this.isUpdatingPhoto,
      photoUpdateError: photoUpdateError,
    );
  }

  @override
  List<Object?> get props => [status, record, errorMessage, isUpdatingPhoto, photoUpdateError];
}
