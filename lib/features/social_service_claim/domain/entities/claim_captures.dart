import 'package:equatable/equatable.dart';

/// The 4 live captures taken during the claim flow (ID front, ID back,
/// signature, claimant's face photo) — local file paths only until
/// submitted.
class ClaimCaptures extends Equatable {
  const ClaimCaptures({
    this.idFrontPath,
    this.idBackPath,
    this.signaturePath,
    this.facePhotoPath,
  });

  final String? idFrontPath;
  final String? idBackPath;
  final String? signaturePath;
  final String? facePhotoPath;

  /// ID Back is optional — the other 3 captures are required.
  bool get isComplete => idFrontPath != null && signaturePath != null && facePhotoPath != null;

  ClaimCaptures copyWith({
    String? idFrontPath,
    String? idBackPath,
    String? signaturePath,
    String? facePhotoPath,
  }) {
    return ClaimCaptures(
      idFrontPath: idFrontPath ?? this.idFrontPath,
      idBackPath: idBackPath ?? this.idBackPath,
      signaturePath: signaturePath ?? this.signaturePath,
      facePhotoPath: facePhotoPath ?? this.facePhotoPath,
    );
  }

  @override
  List<Object?> get props => [idFrontPath, idBackPath, signaturePath, facePhotoPath];
}
