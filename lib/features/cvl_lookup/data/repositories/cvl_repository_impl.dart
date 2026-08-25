import '../../../../core/network/api_client.dart';
import '../../domain/entities/cvl_record.dart';
import '../../domain/repositories/cvl_repository.dart';
import '../datasources/cvl_remote_datasource.dart';

class CvlRepositoryImpl implements CvlRepository {
  CvlRepositoryImpl(this._datasource);

  final CvlRemoteDatasource _datasource;

  @override
  Future<CvlRecord> findByQr(String qrCode) async {
    try {
      final json = await _datasource.findByQr(qrCode);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return CvlRecord.fromJson(data);
    } on ApiException catch (e) {
      throw CvlLookupException(e.message);
    } catch (e) {
      throw CvlLookupException('Network error — could not reach the server: $e');
    }
  }

  @override
  Future<String> updatePhoto({required int id, required String photoPath, String? updatedBy}) async {
    try {
      final json = await _datasource.updatePhoto(id: id, photoPath: photoPath, updatedBy: updatedBy);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final url = (data['cvl_img_path'] ?? '').toString();
      if (url.isEmpty) {
        throw CvlLookupException('Photo was uploaded but the server did not return its URL.');
      }
      return url;
    } on ApiException catch (e) {
      throw CvlLookupException(e.message);
    } on CvlLookupException {
      rethrow;
    } catch (e) {
      throw CvlLookupException('Network error — could not reach the server: $e');
    }
  }
}
