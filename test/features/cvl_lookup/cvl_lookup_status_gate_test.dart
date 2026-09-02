import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/core/theme/app_theme.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_record.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_search_filters.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_search_results_page.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/repositories/cvl_repository.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/find_cvl_by_id.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/find_cvl_by_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/remove_cvl_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/set_cvl_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/update_cvl_info.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/update_cvl_photo.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/bloc/cvl_lookup_cubit.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/bloc/cvl_lookup_state.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart';

const _activeRecord = CvlRecord(
  id: 1,
  cvlId: 'CVL-0001',
  fullName: 'Juan Dela Cruz',
  firstName: 'Juan',
  middleName: '',
  lastName: 'Dela Cruz',
  suffix: '',
  address: '',
  municipality: '',
  barangay: '',
  precinctNo: '',
  birthdate: '',
  contactNo: '09171234567',
  email: '',
  gender: 'Male',
  sector: '',
  qrCode: 'QR-00001',
  imgPath: '',
  status: 'ACTIVE',
);

const _inactiveRecord = CvlRecord(
  id: 1,
  cvlId: 'CVL-0001',
  fullName: 'Juan Dela Cruz',
  firstName: 'Juan',
  middleName: '',
  lastName: 'Dela Cruz',
  suffix: '',
  address: '',
  municipality: '',
  barangay: '',
  precinctNo: '',
  birthdate: '',
  contactNo: '09171234567',
  email: '',
  gender: 'Male',
  sector: '',
  qrCode: 'QR-00001',
  imgPath: '',
  status: 'INACTIVE',
);

class _FakeCvlRepository implements CvlRepository {
  _FakeCvlRepository(this.recordToReturn);

  final CvlRecord recordToReturn;

  @override
  Future<CvlRecord> findByQr(String qrCode) async => recordToReturn;

  @override
  Future<CvlRecord> findById(int id) async => recordToReturn;

  @override
  Future<CvlSearchResultsPage> searchByName(
    String name, {
    int offset = 0,
    CvlSearchFilters filters = const CvlSearchFilters(),
  }) => throw UnimplementedError();

  @override
  Future<CvlFilterOptions> getFilterOptions() => throw UnimplementedError();

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

CvlLookupCubit _buildCubit(CvlRecord recordToReturn) {
  final repository = _FakeCvlRepository(recordToReturn);
  return CvlLookupCubit(
    FindCvlByQr(repository),
    UpdateCvlPhoto(repository),
    FindCvlById(repository),
    UpdateCvlInfo(repository),
    SetCvlQr(repository),
    RemoveCvlQr(repository),
  );
}

void main() {
  group('CvlLookupCubit.fetch status gate', () {
    test('an ACTIVE record loads normally', () async {
      final cubit = _buildCubit(_activeRecord);
      addTearDown(cubit.close);

      await cubit.fetch('QR-00001');

      expect(cubit.state.status, CvlLookupStatus.loaded);
      expect(cubit.state.record, _activeRecord);
    });

    test('a non-ACTIVE record is blocked, not loaded', () async {
      final cubit = _buildCubit(_inactiveRecord);
      addTearDown(cubit.close);

      await cubit.fetch('QR-00001');

      expect(cubit.state.status, CvlLookupStatus.blocked);
      // The record is still attached (so a dialog can reference it), but
      // the scan does not proceed to the loaded/details state.
      expect(cubit.state.record, _inactiveRecord);
    });
  });

  testWidgets(
    'scanning a non-ACTIVE record shows a blocking dialog and pops back '
    'to the scanner instead of showing the details view',
    (tester) async {
      final cubit = _buildCubit(_inactiveRecord);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CvlLookupPage(rawValue: 'QR-00001'),
                  ),
                ),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
      );

      // Not pumpAndSettle: the blocked state's builder holds a
      // CircularProgressIndicator (indeterminate, animates forever)
      // behind the dialog, which would never let pumpAndSettle settle.
      await tester.tap(find.text('scan'));
      await tester.pump(); // process navigation
      await tester.pump(const Duration(milliseconds: 300)); // route transition
      await tester.pump(); // flush the fetch's Future and the dialog route

      expect(find.byType(CvlLookupPage), findsOneWidget);
      expect(find.text('Record Not Active'), findsOneWidget);
      // The details view (name header) must not be reachable underneath.
      expect(find.text(_inactiveRecord.fullName), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog pop
      await tester.pump(const Duration(milliseconds: 300)); // page pop

      // Dialog dismissed and the lookup page itself popped back to the
      // scanner — the scan did not proceed.
      expect(find.byType(CvlLookupPage), findsNothing);
      expect(find.text('scan'), findsOneWidget);
    },
  );

  group('CVL status display on the details view', () {
    // Reached via the search flow (CvlLookupPage.byId), which — unlike
    // scanning — has no active-only gate, so a non-active record's
    // details view is exactly where the status needs to be visible.
    testWidgets('shows ACTIVE for an active record', (tester) async {
      final cubit = _buildCubit(_activeRecord);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const CvlLookupPage.byId(recordId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('shows INACTIVE for a non-active record', (tester) async {
      final cubit = _buildCubit(_inactiveRecord);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const CvlLookupPage.byId(recordId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INACTIVE'), findsOneWidget);
    });
  });
}
