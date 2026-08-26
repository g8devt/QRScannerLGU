import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_record.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/entities/cvl_search_results_page.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/repositories/cvl_repository.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/remove_cvl_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/search_cvl_by_name.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/domain/usecases/set_cvl_qr.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/bloc/cvl_search_cubit.dart';
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/pages/cvl_search_page.dart';

class _FakeCvlRepository implements CvlRepository {
  @override
  Future<CvlRecord> findByQr(String qrCode) => throw UnimplementedError();

  @override
  Future<CvlRecord> findById(int id) => throw UnimplementedError();

  @override
  Future<CvlSearchResultsPage> searchByName(
    String name, {
    int offset = 0,
  }) async => const CvlSearchResultsPage(results: [], hasMore: false);

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
  testWidgets('CvlSearchPage disposes cleanly when popped', (tester) async {
    final repository = _FakeCvlRepository();
    final cubit = CvlSearchCubit(
      SearchCvlByName(repository),
      SetCvlQr(repository),
      RemoveCvlQr(repository),
    );

    // The provider must wrap MaterialApp itself (matching main.dart's real
    // wiring), not just `home` — routes pushed via Navigator are siblings
    // of `home`'s subtree under the Overlay, not descendants of it, so a
    // provider placed only around `home` wouldn't be visible to them.
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CvlSearchPage())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CvlSearchPage), findsOneWidget);

    // Pop immediately — this is what triggered dispose() on a deactivated
    // widget before the fix.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
