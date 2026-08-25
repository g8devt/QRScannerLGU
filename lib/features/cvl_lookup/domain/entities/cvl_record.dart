import 'package:equatable/equatable.dart';

/// A single `app_cvl_list` record, resolved via its assigned
/// `app_qr_code` and returned by `find_cvl_by_qr_bataan`.
class CvlRecord extends Equatable {
  const CvlRecord({
    required this.id,
    required this.cvlId,
    required this.fullName,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.address,
    required this.municipality,
    required this.barangay,
    required this.precinctNo,
    required this.birthdate,
    required this.contactNo,
    required this.email,
    required this.gender,
    required this.sector,
    required this.qrCode,
    required this.imgPath,
  });

  final int id;
  final String cvlId;
  final String fullName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String address;
  final String municipality;
  final String barangay;
  final String precinctNo;
  final String birthdate;
  final String contactNo;
  final String email;
  final String gender;
  final String sector;
  final String qrCode;

  /// `app_cvl_list.cvl_img_path` — may be an absolute URL (photo uploaded
  /// via this app or the KYC-connect flow, both S3) or a relative path
  /// like `storage/cvl/xxx.jpg` (uploaded via the PHP admin, only
  /// reachable from inside its login-gated session — not loadable here).
  /// [hasDisplayableImage] is what UI code should actually check.
  final String imgPath;

  /// Whether [imgPath] is something this app can actually render —
  /// i.e. an absolute URL, not a PHP-admin-relative path.
  bool get hasDisplayableImage => imgPath.startsWith('http://') || imgPath.startsWith('https://');

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory CvlRecord.fromJson(Map<String, dynamic> json) {
    return CvlRecord(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      cvlId: _str(json['cvl_id']),
      fullName: _str(json['cvl_fullname']),
      firstName: _str(json['cvl_fname']),
      middleName: _str(json['cvl_mname']),
      lastName: _str(json['cvl_lname']),
      suffix: _str(json['cvl_suffix']),
      address: _str(json['cvl_address']),
      municipality: _str(json['cvl_mun']),
      barangay: _str(json['cvl_brgy']),
      precinctNo: _str(json['cvl_precinct_no']),
      birthdate: _str(json['cvl_birthdate']),
      contactNo: _str(json['cvl_contact_no']),
      email: _str(json['cvl_email']),
      gender: _str(json['cvl_gender']),
      sector: _str(json['cvl_sector']),
      qrCode: _str(json['cvl_qr_code']),
      imgPath: _str(json['cvl_img_path']),
    );
  }

  CvlRecord copyWith({String? imgPath}) {
    return CvlRecord(
      id: id,
      cvlId: cvlId,
      fullName: fullName,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      suffix: suffix,
      address: address,
      municipality: municipality,
      barangay: barangay,
      precinctNo: precinctNo,
      birthdate: birthdate,
      contactNo: contactNo,
      email: email,
      gender: gender,
      sector: sector,
      qrCode: qrCode,
      imgPath: imgPath ?? this.imgPath,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cvlId,
        fullName,
        firstName,
        middleName,
        lastName,
        suffix,
        address,
        municipality,
        barangay,
        precinctNo,
        birthdate,
        contactNo,
        email,
        gender,
        sector,
        qrCode,
        imgPath,
      ];
}
