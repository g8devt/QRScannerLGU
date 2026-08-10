import 'package:equatable/equatable.dart';

/// A logged-in scanner-staff account, as returned by the
/// `login_scanner_bataan` endpoint's `data` object.
class ScannerUser extends Equatable {
  const ScannerUser({
    required this.id,
    required this.username,
    required this.userStatus,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.suffix,
  });

  final int id;
  final String username;
  final String userStatus;
  final String firstname;
  final String middlename;
  final String lastname;
  final String suffix;

  String get fullName =>
      [firstname, middlename, lastname, suffix].where((s) => s.isNotEmpty).join(' ');

  factory ScannerUser.fromJson(Map<String, dynamic> json) {
    return ScannerUser(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      username: (json['username'] ?? '').toString(),
      userStatus: (json['user_status'] ?? '').toString(),
      firstname: (json['firstname'] ?? '').toString(),
      middlename: (json['middlename'] ?? '').toString(),
      lastname: (json['lastname'] ?? '').toString(),
      suffix: (json['suffix'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'user_status': userStatus,
        'firstname': firstname,
        'middlename': middlename,
        'lastname': lastname,
        'suffix': suffix,
      };

  @override
  List<Object?> get props => [id, username, userStatus, firstname, middlename, lastname, suffix];
}
