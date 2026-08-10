import 'package:equatable/equatable.dart';

/// Data produced by a single successful QR scan, plus anything captured
/// afterwards in the same session (e.g. a verification photo).
class ScannedIdData extends Equatable {
  const ScannedIdData({
    required this.rawValue,
    this.parsedFields = const {},
    this.photoPath,
  });

  /// The raw string payload decoded from the QR code.
  final String rawValue;

  /// Best-effort key/value parse of [rawValue] (empty if it isn't
  /// structured data). Presentation decides how to render this.
  final Map<String, String> parsedFields;

  /// Local file path of a photo captured after the scan, if any.
  final String? photoPath;

  ScannedIdData copyWith({String? photoPath}) {
    return ScannedIdData(
      rawValue: rawValue,
      parsedFields: parsedFields,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  @override
  List<Object?> get props => [rawValue, parsedFields, photoPath];
}
