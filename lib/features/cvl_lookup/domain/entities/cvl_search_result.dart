import 'package:equatable/equatable.dart';

/// One row from `search_cvl_by_name_bataan` — a lightweight summary for
/// the results list. Tapping one loads the full [CvlRecord] via
/// `get_cvl_by_id_bataan`.
class CvlSearchResult extends Equatable {
  const CvlSearchResult({
    required this.id,
    required this.fullName,
    required this.municipality,
    required this.barangay,
    required this.qrCode,
  });

  final int id;
  final String fullName;
  final String municipality;
  final String barangay;

  /// Empty when the record has no QR assigned yet.
  final String qrCode;

  bool get hasQr => qrCode.isNotEmpty;

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory CvlSearchResult.fromJson(Map<String, dynamic> json) {
    return CvlSearchResult(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      fullName: _str(json['cvl_fullname']),
      municipality: _str(json['cvl_mun']),
      barangay: _str(json['cvl_brgy']),
      qrCode: _str(json['cvl_qr_code']),
    );
  }

  @override
  List<Object?> get props => [id, fullName, municipality, barangay, qrCode];
}
