import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/restore_session_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/cvl_lookup/data/datasources/cvl_remote_datasource.dart';
import 'features/cvl_lookup/data/repositories/cvl_repository_impl.dart';
import 'features/cvl_lookup/domain/usecases/find_cvl_by_qr.dart';
import 'features/cvl_lookup/domain/usecases/update_cvl_photo.dart';
import 'features/cvl_lookup/presentation/bloc/cvl_lookup_cubit.dart';
import 'features/qr_scanner/data/datasources/image_picker_datasource.dart';
import 'features/qr_scanner/data/datasources/mobile_scanner_datasource.dart';
import 'features/qr_scanner/data/repositories/camera_repository_impl.dart';
import 'features/qr_scanner/data/repositories/scanner_repository_impl.dart';
import 'features/qr_scanner/domain/usecases/capture_photo.dart';
import 'features/qr_scanner/presentation/bloc/scanner_bloc.dart';
import 'features/social_service_claim/data/datasources/claim_remote_datasource.dart';
import 'features/social_service_claim/data/repositories/claim_repository_impl.dart';
import 'features/social_service_claim/domain/usecases/get_service_details.dart';
import 'features/social_service_claim/domain/usecases/submit_claim.dart';
import 'features/social_service_claim/domain/usecases/verify_qr.dart';
import 'features/social_service_claim/presentation/bloc/claim_bloc.dart';
import 'features/social_service_claim/presentation/bloc/service_details_cubit.dart';

final RouteObserver<PageRoute<void>> routeObserver = RouteObserver<PageRoute<void>>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initPackageInfo();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => MobileScannerDatasource(),
      dispose: (datasource) => datasource.dispose(),
      child: Builder(
        builder: (context) {
          final scannerDatasource = context.read<MobileScannerDatasource>();
          final imagePickerDatasource = ImagePickerDatasource();
          final scannerRepository = ScannerRepositoryImpl(scannerDatasource);
          final cameraRepository = CameraRepositoryImpl(imagePickerDatasource);
          final capturePhoto = CapturePhoto(cameraRepository);

          final apiClient = ApiClient();
          final claimRemoteDatasource = ClaimRemoteDatasource(apiClient);
          final claimRepository = ClaimRepositoryImpl(claimRemoteDatasource);
          final verifyQr = VerifyQr(claimRepository);
          final submitClaim = SubmitClaim(claimRepository);
          final getServiceDetails = GetServiceDetails(claimRepository);

          final cvlRemoteDatasource = CvlRemoteDatasource(apiClient);
          final cvlRepository = CvlRepositoryImpl(cvlRemoteDatasource);
          final findCvlByQr = FindCvlByQr(cvlRepository);
          final updateCvlPhoto = UpdateCvlPhoto(cvlRepository);

          final authRemoteDatasource = AuthRemoteDatasource(apiClient);
          final authLocalDatasource = AuthLocalDatasource();
          final authRepository = AuthRepositoryImpl(authRemoteDatasource, authLocalDatasource);
          final loginUsecase = LoginUsecase(authRepository);
          final logoutUsecase = LogoutUsecase(authRepository);
          final restoreSessionUsecase = RestoreSessionUsecase(authRepository);

          return RepositoryProvider<CapturePhoto>(
            create: (_) => capturePhoto,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => ScannerBloc(scannerRepository)),
                BlocProvider(create: (_) => ClaimBloc(verifyQr, submitClaim)),
                BlocProvider(create: (_) => ServiceDetailsCubit(getServiceDetails)),
                BlocProvider(create: (_) => CvlLookupCubit(findCvlByQr, updateCvlPhoto)),
                BlocProvider(create: (_) => AuthBloc(loginUsecase, logoutUsecase, restoreSessionUsecase)),
              ],
              child: MaterialApp(
                title: 'Bataan LGU Scanner',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
                navigatorObservers: [routeObserver],
                home: const AuthGate(),
              ),
            ),
          );
        },
      ),
    );
  }
}
