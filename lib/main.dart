import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/api_client.dart';
import 'features/qr_scanner/data/datasources/image_picker_datasource.dart';
import 'features/qr_scanner/data/datasources/mobile_scanner_datasource.dart';
import 'features/qr_scanner/data/repositories/camera_repository_impl.dart';
import 'features/qr_scanner/data/repositories/scanner_repository_impl.dart';
import 'features/qr_scanner/domain/usecases/capture_photo.dart';
import 'features/qr_scanner/presentation/bloc/scanner_bloc.dart';
import 'features/qr_scanner/presentation/pages/scanner_page.dart';
import 'features/social_service_claim/data/datasources/claim_remote_datasource.dart';
import 'features/social_service_claim/data/repositories/claim_repository_impl.dart';
import 'features/social_service_claim/domain/usecases/submit_claim.dart';
import 'features/social_service_claim/domain/usecases/verify_qr.dart';
import 'features/social_service_claim/presentation/bloc/claim_bloc.dart';

final RouteObserver<PageRoute<void>> routeObserver = RouteObserver<PageRoute<void>>();

void main() {
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

          return RepositoryProvider<CapturePhoto>(
            create: (_) => capturePhoto,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => ScannerBloc(scannerRepository)),
                BlocProvider(create: (_) => ClaimBloc(verifyQr, submitClaim)),
              ],
              child: MaterialApp(
                title: 'Bataan LGU Scanner',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
                navigatorObservers: [routeObserver],
                home: const ScannerPage(),
              ),
            ),
          );
        },
      ),
    );
  }
}
