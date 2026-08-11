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
  const ClaimSubmitRequested({this.usersScannerId});

  /// The logged-in scanner-staff account's id (`AuthBloc`'s current
  /// `ScannerUser.id`), recorded on the claim so it can be traced back to
  /// who processed it. Null when no one is logged in (shouldn't happen
  /// past `AuthGate`, but the backend column is nullable regardless).
  final int? usersScannerId;

  @override
  List<Object?> get props => [usersScannerId];
}

/// Resets the whole session — used after Stop or after a successful claim,
/// before returning to the scanner.
class ClaimSessionReset extends ClaimEvent {
  const ClaimSessionReset();
}
