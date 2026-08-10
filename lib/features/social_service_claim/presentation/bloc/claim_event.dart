import 'package:equatable/equatable.dart';

import '../../domain/entities/claim_captures.dart';
import '../../domain/entities/claimant_info.dart';

abstract class ClaimEvent extends Equatable {
  const ClaimEvent();

  @override
  List<Object?> get props => [];
}

/// Kicks off `verify_qr_bataan` for the just-scanned code.
class VerifyQrRequested extends ClaimEvent {
  const VerifyQrRequested(this.qrCode);

  final String qrCode;

  @override
  List<Object?> get props => [qrCode];
}

/// Stores the claimant-type form (self/representative + ID details).
class ClaimantInfoSaved extends ClaimEvent {
  const ClaimantInfoSaved(this.info);

  final ClaimantInfo info;

  @override
  List<Object?> get props => [info];
}

/// Staff manually confirmed the physical person matches the record.
class IdentityConfirmed extends ClaimEvent {
  const IdentityConfirmed();
}

/// A capture step completed (or was retaken); replaces the whole
/// [ClaimCaptures] snapshot.
class CapturesUpdated extends ClaimEvent {
  const CapturesUpdated(this.captures);

  final ClaimCaptures captures;

  @override
  List<Object?> get props => [captures];
}

/// Submits the claim (calls `submit_claim_bataan`).
class ClaimSubmitRequested extends ClaimEvent {
  const ClaimSubmitRequested();
}

/// Resets the whole session — used after Stop or after a successful claim,
/// before returning to the scanner.
class ClaimSessionReset extends ClaimEvent {
  const ClaimSessionReset();
}
