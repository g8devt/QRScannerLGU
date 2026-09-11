import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_record.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_search_filters.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_search_results_page.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/repositories/cvl_repository.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/get_cvl_filter_options.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/remove_cvl_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/search_cvl_by_name.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/set_cvl_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/bloc/cvl_search_cubit.dart';

/// Fake repository that just records the [name] passed to `searchByName`
/// so the test can assert on it.
class _RecordingCvlRepository implements CvlRepository {
  String? lastName;

  @override
  Future<CvlRecord> findByQr(String qrCode) => throw UnimplementedError();

  @override
  Future<CvlRecord> findById(int id) => throw UnimplementedError();

  @override
  Future<CvlSearchResultsPage> searchByName(
    String name, {
    int offset = 0,
    CvlSearchFilters filters = const CvlSearchFilters(),
  }) async {
    lastName = name;
    return const CvlSearchResultsPage(results: [], hasMore: false);
  }

  @override
  Future<CvlFilterOptions> getFilterOptions() async => const CvlFilterOptions();

  @override
  Future<String> updatePhoto({
    required int id,
    required String photoPath,
    String? updatedBy,
  }) => throw UnimplementedError();

  @override
  Future<String> setQr({required int id, required String qrCode}) =>
      throw UnimplementedError();

  @override
  Future<void> removeQr({required int id}) => throw UnimplementedError();

  @override
  Future<(String, String, String)> updateInfo({
    required int id,
    String? contactNo,
    String? email,
    String? gender,
    String? updatedBy,
  }) => throw UnimplementedError();
}

void main() {
  test(
    'reset() clears the remembered search term, so a later filter-only '
    'applyFilters() does not silently re-add a stale name from a previous '
    'visit to the search page',
    () async {
      final repository = _RecordingCvlRepository();
      final cubit = CvlSearchCubit(
        SearchCvlByName(repository),
        SetCvlQr(repository),
        RemoveCvlQr(repository),
        GetCvlFilterOptions(repository),
      );

      // Staff member types a name on the search page...
      await cubit.search('megan');
      expect(repository.lastName, 'megan');

      // ...then navigates away. CvlSearchPage.dispose() calls reset().
      cubit.reset();

      // They come back to a fresh CvlSearchPage (new, empty text field)
      // and, without typing anything, just apply a filter.
      await cubit.applyFilters(
        const CvlSearchFilters(hasPhoto: TriState.yes),
      );

      // The filter-only search must not be scoped to the old "megan" term.
      expect(repository.lastName, '');
    },
  );
}
