import '../entities/cvl_record.dart';
import '../entities/cvl_search_results_page.dart';

abstract class CvlRepository {
  /// Looks up [qrCode] against the backend. Returns the matching CVL
  /// record. Throws [CvlLookupException] with a human-readable reason
  /// on any rejection (not found) or network failure.
  Future<CvlRecord> findByQr(String qrCode);

  /// Looks up the CVL record with primary key [id] — the search flow's
  /// counterpart to [findByQr]. Returns the matching record even if it
  /// has no QR assigned yet. Throws [CvlLookupException] with a
  /// human-readable reason on any rejection (not found) or network
  /// failure.
  Future<CvlRecord> findById(int id);

  /// Searches by full [name] (at least 2 characters), returning the page
  /// of up to 25 lightweight matches starting at [offset] — including
  /// records with no QR assigned yet — plus whether another page exists
  /// beyond it. Throws [CvlLookupException] with a human-readable reason
  /// on any rejection or network failure.
  Future<CvlSearchResultsPage> searchByName(String name, {int offset});

  /// Uploads [photoPath] (a local file path) as the new photo for the CVL
  /// record [id], attributed to [updatedBy] (the logged-in scanner
  /// username, if known). Returns the new `cvl_img_path` URL. Throws
  /// [CvlLookupException] with a human-readable reason on any rejection
  /// (record not found) or network failure.
  Future<String> updatePhoto({
    required int id,
    required String photoPath,
    String? updatedBy,
  });

  /// Assigns [qrCode] (freshly scanned) to the CVL record [id]. The
  /// backend rejects — via [CvlLookupException] — a code that isn't
  /// registered in `app_qr_code` or one that's already in use. Returns
  /// the assigned code on success.
  Future<String> setQr({required int id, required String qrCode});

  /// Unassigns whatever QR code is currently set on CVL record [id],
  /// freeing it in `app_qr_code` for reuse. Throws [CvlLookupException]
  /// — via a human-readable reason — if the record has no QR assigned,
  /// doesn't exist, or on network failure.
  Future<void> removeQr({required int id});

  /// Updates CVL record [id]'s contact number, email, and/or gender —
  /// whichever of [contactNo]/[email]/[gender] is non-null (at least one
  /// must be). Everything else on the record is read-only from this app.
  /// Returns the updated `(contactNo, email, gender)` triple. Throws
  /// [CvlLookupException] with a human-readable reason on rejection
  /// (record not found) or network failure.
  Future<(String, String, String)> updateInfo({
    required int id,
    String? contactNo,
    String? email,
    String? gender,
    String? updatedBy,
  });
}

class CvlLookupException implements Exception {
  CvlLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}
