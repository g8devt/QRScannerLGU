import '../../../../core/network/api_client.dart';
import '../../domain/entities/cvl_record.dart';
import '../../domain/entities/cvl_search_results_page.dart';
import '../../domain/entities/cvl_search_result.dart';
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
      throw CvlLookupException(
        'Network error — could not reach the server: $e',
      );
    }
  }

  @override
  Future<CvlRecord> findById(int id) async {
    try {
      final json = await _datasource.findById(id);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return CvlRecord.fromJson(data);
    } on ApiException catch (e) {
      throw CvlLookupException(e.message);
    } catch (e) {
      throw CvlLookupException(
        'Network error — could not reach the server: $e',
      );
    }
  }

  @override
  Future<CvlSearchResultsPage> searchByName(
    String name, {
    int offset = 0,
  }) async {
    try {
      final json = await _datasource.searchByName(name, offset: offset);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final results = data['results'] as List<dynamic>? ?? [];
      return CvlSearchResultsPage(
        results: results
            .map((r) => CvlSearchResult.fromJson(r as Map<String, dynamic>))
            .toList(),
        hasMore: data['has_more'] == true,
      );
    } on ApiException catch (e) {
      throw CvlLookupException(e.message);
    } catch (e) {
      throw CvlLookupException(
        'Network error — could not reach the server: $e',
      );
    }
  }

  @override
  Future<String> updatePhoto({
    required int id,
    required String photoPath,
    String? updatedBy,
  }) async {
    try {
      final json = await _datasource.updatePhoto(
        id: id,
        photoPath: photoPath,
        updatedBy: updatedBy,
      );
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final url = (data['cvl_img_path'] ?? '').toString();
      if (url.isEmpty) {
        throw CvlLookupException(
          'Photo was uploaded but the server did not return its URL.',
        );
      }
      return url;
    } on ApiException catch (e) {
      throw CvlLookupException(e.message);
    } on CvlLookupException {
      rethrow;
    } catch (e) {
      throw CvlLookupException(
        'Network error — could not reach the server: $e',
      );
    }
  }
}
