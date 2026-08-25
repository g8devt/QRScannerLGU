import '../entities/cvl_record.dart';

abstract class CvlRepository {
  /// Looks up [qrCode] against the backend. Returns the matching CVL
  /// record. Throws [CvlLookupException] with a human-readable reason
  /// on any rejection (not found) or network failure.
  Future<CvlRecord> findByQr(String qrCode);
}

class CvlLookupException implements Exception {
  CvlLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}
