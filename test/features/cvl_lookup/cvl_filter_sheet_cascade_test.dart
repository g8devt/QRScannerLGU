import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/widgets/cvl_filter_sheet.dart';

const _options = CvlFilterOptions(
  majorPositions: ['ATR', 'BECS'],
  leaderTitlesByPosition: {
    'ATR': ['MAIN COORDINATOR', 'PUROK COORDINATOR'],
    'BECS': ['PRESIDENT'],
  },
);

class _FakeCvlRepository implements CvlRepository {
  const _FakeCvlRepository();

  @override
  Future<CvlRecord> findByQr(String qrCode) => throw UnimplementedError();

  @override
  Future<CvlRecord> findById(int id) => throw UnimplementedError();

  @override
  Future<CvlSearchResultsPage> searchByName(
    String name, {
    int offset = 0,
    CvlSearchFilters filters = const CvlSearchFilters(),
  }) => throw UnimplementedError();

  @override
  Future<CvlFilterOptions> getFilterOptions() async => _options;

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
  testWidgets(
    'Leader Title options cascade from the selected Major Position, and '
    'reset when it no longer applies',
    (tester) async {
      // Tall surface so every filter field is on-screen without needing to
      // scroll first — the sheet's real host (showModalBottomSheet) sizes
      // to content, but this test hosts it directly in a Scaffold body.
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const repository = _FakeCvlRepository();
      final cubit = CvlSearchCubit(
        SearchCvlByName(repository),
        SetCvlQr(repository),
        RemoveCvlQr(repository),
        GetCvlFilterOptions(repository),
      );
      await cubit.loadFilterOptions();

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(
            home: Scaffold(body: CvlFilterSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Before picking a major position, Leader Title shows every title
      // across all positions, flattened.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Leader title'));
      await tester.pumpAndSettle();
      expect(find.text('MAIN COORDINATOR'), findsOneWidget);
      expect(find.text('PUROK COORDINATOR'), findsOneWidget);
      expect(find.text('PRESIDENT'), findsOneWidget);
      await tester.tap(find.text('PUROK COORDINATOR').last);
      await tester.pumpAndSettle();

      // Pick ATR as the major position — PUROK COORDINATOR is still valid
      // under ATR, so it must stay selected, not silently clear.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Major position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ATR').last);
      await tester.pumpAndSettle();
      expect(find.text('PUROK COORDINATOR'), findsOneWidget);

      // Switch to BECS — PUROK COORDINATOR isn't valid there, so it must
      // clear rather than keep silently applying a stale filter the
      // dropdown no longer shows as selected.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Major position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BECS').last);
      await tester.pumpAndSettle();
      expect(find.text('PUROK COORDINATOR'), findsNothing);

      // And the Leader Title dropdown itself now only offers BECS's titles.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Leader title'));
      await tester.pumpAndSettle();
      expect(find.text('PRESIDENT'), findsOneWidget);
      expect(find.text('MAIN COORDINATOR'), findsNothing);
      expect(find.text('PUROK COORDINATOR'), findsNothing);
    },
  );
}
