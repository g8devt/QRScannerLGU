import 'package:equatable/equatable.dart';

import '../../domain/entities/claim_captures.dart';
import '../../domain/entities/claimant_info.dart';
import '../../domain/entities/verified_application.dart';

enum ClaimStatus {
  initial,
  verifying,
  verifyFailed,
  verified,
  submitting,
  submitFailed,
  submitted,
}

class ClaimState extends Equatable {
  const ClaimState({
    this.status = ClaimStatus.initial,
    this.application,
    this.claimant = const ClaimantInfo(type: ClaimantType.self, idType: '', idNumber: ''),
    this.identityConfirmed = false,
    this.captures = const ClaimCaptures(),
    this.errorMessage,
  });

  final ClaimStatus status;
  final VerifiedApplication? application;
  final ClaimantInfo claimant;
  final bool identityConfirmed;
  final ClaimCaptures captures;
  final String? errorMessage;

  ClaimState copyWith({
    ClaimStatus? status,
    VerifiedApplication? application,
    ClaimantInfo? claimant,
    bool? identityConfirmed,
    ClaimCaptures? captures,
    String? errorMessage,
  }) {
    return ClaimState(
      status: status ?? this.status,
      application: application ?? this.application,
      claimant: claimant ?? this.claimant,
      identityConfirmed: identityConfirmed ?? this.identityConfirmed,
      captures: captures ?? this.captures,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, application, claimant, identityConfirmed, captures, errorMessage];
}
