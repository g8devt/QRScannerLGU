import '../entities/cvl_record.dart';

abstract class CvlRepository {
  /// Looks up [qrCode] against the backend. Returns the matching CVL
  /// record. Throws [CvlLookupException] with a human-readable reason
  /// on any rejection (not found) or network failure.
  Future<CvlRecord> findByQr(String qrCode);

  /// Uploads [photoPath] (a local file path) as the new photo for the CVL
  /// record [id], attributed to [updatedBy] (the logged-in scanner
  /// username, if known). Returns the new `cvl_img_path` URL. Throws
  /// [CvlLookupException] with a human-readable reason on any rejection
  /// (record not found) or network failure.
  Future<String> updatePhoto({required int id, required String photoPath, String? updatedBy});
}

class CvlLookupException implements Exception {
  CvlLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}
