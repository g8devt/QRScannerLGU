import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/entities/scanner_user.dart';

void main() {
  test('fromJson parses all fields and toJson round-trips them', () {
    final json = {
      'id': 7,
      'username': 'staff1',
      'user_status': 'VERIFIED',
      'firstname': 'Juan',
      'middlename': '',
      'lastname': 'Dela Cruz',
      'suffix': '',
    };

    final user = ScannerUser.fromJson(json);

    expect(user.id, 7);
    expect(user.username, 'staff1');
    expect(user.userStatus, 'VERIFIED');
    expect(user.fullName, 'Juan Dela Cruz');
    expect(user.toJson(), json);
  });

  test('fromJson defaults missing string fields to empty string', () {
    final user = ScannerUser.fromJson({'id': 1});

    expect(user.username, '');
    expect(user.userStatus, '');
    expect(user.fullName, '');
  });
}
