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
      ];
}
