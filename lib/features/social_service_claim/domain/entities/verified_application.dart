import 'package:equatable/equatable.dart';

/// The application record returned by `verify_qr_bataan` once eligibility
/// gates (status, not already claimed) have passed server-side.
class VerifiedApplication extends Equatable {
  const VerifiedApplication({
    required this.id,
    required this.applicationNumber,
    required this.beneficiaryName,
    required this.status,
    required this.requestedForFname,
    required this.requestedForMname,
    required this.requestedForLname,
  });

  final int id;
  final String applicationNumber;
  final String beneficiaryName;
  final String status;
  final String requestedForFname;
  final String requestedForMname;
  final String requestedForLname;

  String get applicantFullName => [requestedForFname, requestedForMname, requestedForLname]
      .where((s) => s.isNotEmpty)
      .join(' ');

  factory VerifiedApplication.fromJson(Map<String, dynamic> json) {
    return VerifiedApplication(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      applicationNumber: (json['application_number'] ?? '').toString(),
      beneficiaryName: (json['beneficiary_name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      requestedForFname: (json['requested_for_fname'] ?? '').toString(),
      requestedForMname: (json['requested_for_mname'] ?? '').toString(),
      requestedForLname: (json['requested_for_lname'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        applicationNumber,
        beneficiaryName,
        status,
        requestedForFname,
        requestedForMname,
        requestedForLname,
      ];
}
