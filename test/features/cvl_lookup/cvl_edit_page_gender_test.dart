import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bataan_lgu_scanner/features/auth/domain/entities/scanner_user.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/login_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/logout_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_bloc.dart';
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
import 'package:bataan_lgu_scanner/features/cvl_lookup/presentation/pages/cvl_edit_page.dart';
import 'package:bataan_lgu_scanner/features/qr_scanner/data/repositories/camera_repository_impl.dart';
import 'package:bataan_lgu_scanner/features/qr_scanner/data/datasources/image_picker_datasource.dart';
import 'package:bataan_lgu_scanner/features/qr_scanner/domain/usecases/capture_photo.dart';

class _FakeCvlRepository implements CvlRepository {
  const _FakeCvlRepository();

  @override
  Future<CvlRecord> findById(int id) async => const CvlRecord(
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
    // Legacy free-text value — not "Male"/"Female" — this is exactly
    // what crashed DropdownButtonFormField before the fix.
    gender: 'MALE',
    sector: '',
    qrCode: '',
    imgPath: '',
    status: 'ACTIVE',
  );

  @override
  Future<CvlRecord> findByQr(String qrCode) => throw UnimplementedError();

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

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) => throw UnimplementedError();

  @override
  Future<ScannerUser?> restoreSession() async => null;

  @override
  Future<void> logout() => throw UnimplementedError();
}

void main() {
  testWidgets(
    'CvlEditPage renders without crashing when cvl_gender is a legacy '
    'value like "MALE" that does not exactly match the dropdown options',
    (tester) async {
      const repository = _FakeCvlRepository();
      const authRepository = _FakeAuthRepository();
      final cubit = CvlLookupCubit(
        FindCvlByQr(repository),
        UpdateCvlPhoto(repository),
        FindCvlById(repository),
        UpdateCvlInfo(repository),
        SetCvlQr(repository),
        RemoveCvlQr(repository),
      );
      addTearDown(cubit.close);
      final authBloc = AuthBloc(
        LoginUsecase(authRepository),
        LogoutUsecase(authRepository),
        RestoreSessionUsecase(authRepository),
      );
      addTearDown(authBloc.close);
      final capturePhoto = CapturePhoto(
        CameraRepositoryImpl(ImagePickerDatasource()),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: authBloc),
          ],
          child: RepositoryProvider.value(
            value: capturePhoto,
            child: const MaterialApp(home: CvlEditPage(recordId: 1)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('MALE'), findsOneWidget);
    },
  );
}
