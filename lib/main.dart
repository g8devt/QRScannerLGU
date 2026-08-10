import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/qr_scanner/data/datasources/image_picker_datasource.dart';
import 'features/qr_scanner/data/datasources/mobile_scanner_datasource.dart';
import 'features/qr_scanner/data/repositories/camera_repository_impl.dart';
import 'features/qr_scanner/data/repositories/scanner_repository_impl.dart';
import 'features/qr_scanner/domain/usecases/capture_photo.dart';
import 'features/qr_scanner/presentation/bloc/capture_bloc.dart';
import 'features/qr_scanner/presentation/bloc/scanner_bloc.dart';
import 'features/qr_scanner/presentation/pages/scanner_page.dart';

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

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => ScannerBloc(scannerRepository)),
              BlocProvider(create: (_) => CaptureBloc(capturePhoto)),
            ],
            child: MaterialApp(
              title: 'Bataan LGU Scanner',
              theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
              home: const ScannerPage(),
            ),
          );
        },
      ),
    );
  }
}
