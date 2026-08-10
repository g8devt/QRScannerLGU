import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/submit_claim.dart';
import '../../domain/usecases/verify_qr.dart';
import 'claim_event.dart';
import 'claim_state.dart';

class ClaimBloc extends Bloc<ClaimEvent, ClaimState> {
  ClaimBloc(this._verifyQr, this._submitClaim) : super(const ClaimState()) {
    on<VerifyQrRequested>(_onVerifyQrRequested);
    on<ClaimantInfoSaved>(_onClaimantInfoSaved);
    on<IdentityConfirmed>(_onIdentityConfirmed);
    on<CapturesUpdated>(_onCapturesUpdated);
    on<ClaimSubmitRequested>(_onClaimSubmitRequested);
    on<ClaimSessionReset>(_onClaimSessionReset);
  }

  final VerifyQr _verifyQr;
  final SubmitClaim _submitClaim;

  Future<void> _onVerifyQrRequested(VerifyQrRequested event, Emitter<ClaimState> emit) async {
    emit(state.copyWith(status: ClaimStatus.verifying));
    try {
      final application = await _verifyQr(event.qrCode);
      emit(state.copyWith(status: ClaimStatus.verified, application: application));
    } catch (e) {
      emit(state.copyWith(status: ClaimStatus.verifyFailed, errorMessage: e.toString()));
    }
  }

  void _onClaimantInfoSaved(ClaimantInfoSaved event, Emitter<ClaimState> emit) {
    emit(state.copyWith(claimant: event.info));
  }

  void _onIdentityConfirmed(IdentityConfirmed event, Emitter<ClaimState> emit) {
    emit(state.copyWith(identityConfirmed: true));
  }

  void _onCapturesUpdated(CapturesUpdated event, Emitter<ClaimState> emit) {
    emit(state.copyWith(captures: event.captures));
  }

  Future<void> _onClaimSubmitRequested(ClaimSubmitRequested event, Emitter<ClaimState> emit) async {
    final application = state.application;
    if (application == null) {
      emit(state.copyWith(
        status: ClaimStatus.submitFailed,
        errorMessage: 'No verified application in session.',
      ));
      return;
    }
    emit(state.copyWith(status: ClaimStatus.submitting));
    try {
      await _submitClaim(
        applicationId: application.id,
        claimant: state.claimant,
        captures: state.captures,
      );
      emit(state.copyWith(status: ClaimStatus.submitted));
    } catch (e) {
      emit(state.copyWith(status: ClaimStatus.submitFailed, errorMessage: e.toString()));
    }
  }

  void _onClaimSessionReset(ClaimSessionReset event, Emitter<ClaimState> emit) {
    emit(const ClaimState());
  }
}
