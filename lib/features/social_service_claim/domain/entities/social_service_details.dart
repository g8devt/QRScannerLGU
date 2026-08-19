import 'package:equatable/equatable.dart';

/// One uploaded supporting document — a label (e.g. "Barangay Certificate")
/// paired with its S3 URL.
class ServiceDocument extends Equatable {
  const ServiceDocument({required this.label, required this.url});

  final String label;
  final String url;

  @override
  List<Object?> get props => [label, url];
}

/// Full application record returned by `get_service_details_bataan` for
/// read-only viewing — unlike [VerifiedApplication], this is not gated on
/// claim eligibility and may reflect any status.
class SocialServiceDetails extends Equatable {
  const SocialServiceDetails({
    required this.id,
    required this.applicationNumber,
    required this.serviceType,
    required this.serviceSubCategory,
    required this.status,
    required this.beneficiaryName,
    required this.requestedForFname,
    required this.requestedForMname,
    required this.requestedForLname,
    required this.requestedForRelation,
    required this.requestedForBirthdate,
    required this.requestedForGender,
    required this.requestedForContact,
    required this.requestedForEmail,
    required this.requestedForAddress,
    required this.requestedForBarangay,
    required this.requestedForMunicipality,
    required this.requestedForProvince,
    required this.assistanceType,
    required this.briefDescription,
    required this.amount,
    required this.claimedAmount,
    required this.dateRequested,
    required this.dateApproved,
    required this.dateScheduled,
    required this.dateReleased,
    required this.dateClaimed,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.appointmentLocation,
    required this.photo2x2,
    required this.photoSignature,
    required this.imageVerification,
    required this.documents,
  });

  final int id;
  final String applicationNumber;
  final String serviceType;
  final String serviceSubCategory;
  final String status;
  final String beneficiaryName;
  final String requestedForFname;
  final String requestedForMname;
  final String requestedForLname;
  final String requestedForRelation;
  final String requestedForBirthdate;
  final String requestedForGender;
  final String requestedForContact;
  final String requestedForEmail;
  final String requestedForAddress;
  final String requestedForBarangay;
  final String requestedForMunicipality;
  final String requestedForProvince;
  final String assistanceType;
  final String briefDescription;
  final String amount;
  final String claimedAmount;
  final String dateRequested;
  final String dateApproved;
  final String dateScheduled;
  final String dateReleased;
  final String dateClaimed;
  final String appointmentDate;
  final String appointmentTime;
  final String appointmentLocation;
  final String photo2x2;
  final String photoSignature;
  final String imageVerification;
  final List<ServiceDocument> documents;

  String get applicantFullName => [requestedForFname, requestedForMname, requestedForLname]
      .where((s) => s.isNotEmpty)
      .join(' ');

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory SocialServiceDetails.fromJson(Map<String, dynamic> json) {
    return SocialServiceDetails(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      applicationNumber: _str(json['application_number']),
      serviceType: _str(json['service_type']),
      serviceSubCategory: _str(json['service_sub_category']),
      status: _str(json['status']),
      beneficiaryName: _str(json['beneficiary_name']),
      requestedForFname: _str(json['requested_for_fname']),
      requestedForMname: _str(json['requested_for_mname']),
      requestedForLname: _str(json['requested_for_lname']),
      requestedForRelation: _str(json['requested_for_relation']),
      requestedForBirthdate: _str(json['requested_for_birthdate']),
      requestedForGender: _str(json['requested_for_gender']),
      requestedForContact: _str(json['requested_for_contact']),
      requestedForEmail: _str(json['requested_for_email']),
      requestedForAddress: _str(json['requested_for_address']),
      requestedForBarangay: _str(json['requested_for_barangay']),
      requestedForMunicipality: _str(json['requested_for_municipality']),
      requestedForProvince: _str(json['requested_for_province']),
      assistanceType: _str(json['assistance_type']),
      briefDescription: _str(json['brief_description']),
      amount: _str(json['amount']),
      claimedAmount: _str(json['claimed_amount']),
      dateRequested: _str(json['date_requested']),
      dateApproved: _str(json['date_approved']),
      dateScheduled: _str(json['date_scheduled']),
      dateReleased: _str(json['date_released']),
      dateClaimed: _str(json['date_claimed']),
      appointmentDate: _str(json['appointment_date']),
      appointmentTime: _str(json['appointment_time']),
      appointmentLocation: _str(json['appointment_location']),
      photo2x2: _str(json['photo_2x2']),
      photoSignature: _str(json['photo_signature']),
      imageVerification: _str(json['image_verification']),
      documents: [
        for (var n = 1; n <= 8; n++)
          if (_str(json['upload_file_$n']).isNotEmpty)
            ServiceDocument(
              label: _str(json['upload_file_${n}_type']).isNotEmpty
                  ? _str(json['upload_file_${n}_type'])
                  : 'Document $n',
              url: _str(json['upload_file_$n']),
            ),
      ],
    );
  }

  @override
  List<Object?> get props => [
        id,
        applicationNumber,
        serviceType,
        serviceSubCategory,
        status,
        beneficiaryName,
        requestedForFname,
        requestedForMname,
        requestedForLname,
        requestedForRelation,
        requestedForBirthdate,
        requestedForGender,
        requestedForContact,
        requestedForEmail,
        requestedForAddress,
        requestedForBarangay,
        requestedForMunicipality,
        requestedForProvince,
        assistanceType,
        briefDescription,
        amount,
        claimedAmount,
        dateRequested,
        dateApproved,
        dateScheduled,
        dateReleased,
        dateClaimed,
        appointmentDate,
        appointmentTime,
        appointmentLocation,
        photo2x2,
        photoSignature,
        imageVerification,
        documents,
      ];
}
