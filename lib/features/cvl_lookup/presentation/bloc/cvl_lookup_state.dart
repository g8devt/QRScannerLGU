import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_record.dart';

enum CvlLookupStatus { initial, loading, loaded, failed }

class CvlLookupState extends Equatable {
  const CvlLookupState({
    this.status = CvlLookupStatus.initial,
    this.record,
    this.errorMessage,
  });

  final CvlLookupStatus status;
  final CvlRecord? record;
  final String? errorMessage;

  CvlLookupState copyWith({
    CvlLookupStatus? status,
    CvlRecord? record,
    String? errorMessage,
  }) {
    return CvlLookupState(
      status: status ?? this.status,
      record: record ?? this.record,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, record, errorMessage];
}
