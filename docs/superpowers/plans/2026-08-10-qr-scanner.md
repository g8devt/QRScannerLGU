# QR Scanner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default Flutter counter app with a QR scanner feature (scan → result → local photo capture), built with pragmatic clean architecture, no backend/API calls.

**Architecture:** `lib/features/qr_scanner/{domain,data,presentation}` — `domain` is pure Dart (entities + abstract repositories + usecase), `data` implements those contracts with `mobile_scanner` and `image_picker`, `presentation` uses `flutter_bloc` and depends only on `domain`. Wiring happens in `main.dart` via `RepositoryProvider`/`BlocProvider`.

**Tech Stack:** Flutter 3.38 / Dart 3.10, `mobile_scanner`, `flutter_bloc`, `equatable`, `image_picker`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-10-qr-scanner-design.md`
- No network/API calls anywhere in this feature (per spec "Out of scope").
- `domain/` must have zero Flutter or plugin imports (pure Dart only).
- `data/` is the only layer allowed to import `mobile_scanner` / `image_picker`.
- `presentation/` depends only on `domain` (never imports `data` directly).
- Android only for this pass; no iOS permission/config work.
- No automated tests in this pass (spec explicitly defers them) — verification is `flutter analyze` plus (where noted) a manual `flutter run` check. Every task still ends in a compilable, analyzable state.
- Commit after every task.

---

### Task 1: Add dependencies and Android camera permission

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: `mobile_scanner`, `flutter_bloc`, `equatable`, `image_picker` available as imports for all later tasks.

- [ ] **Step 1: Add packages**

Run:
```bash
flutter pub add mobile_scanner flutter_bloc equatable image_picker
```

This updates `pubspec.yaml` and `pubspec.lock` with the latest compatible versions.

- [ ] **Step 2: Add camera permission to the Android manifest**

Open `android/app/src/main/AndroidManifest.xml`. Add the permission tag as the first child of `<manifest>`, before `<application>`:

```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
```

- [ ] **Step 3: Verify the project still builds**

Run: `flutter pub get && flutter analyze`
Expected: no errors (warnings about unused new dependencies are fine, nothing imports them yet).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "chore: add QR scanner dependencies and camera permission"
```

---

### Task 2: Domain layer — entity, repository interfaces, usecase

**Files:**
- Create: `lib/features/qr_scanner/domain/entities/scanned_id_data.dart`
- Create: `lib/features/qr_scanner/domain/repositories/scanner_repository.dart`
- Create: `lib/features/qr_scanner/domain/repositories/camera_repository.dart`
- Create: `lib/features/qr_scanner/domain/usecases/capture_photo.dart`

**Interfaces:**
- Produces:
  - `class ScannedIdData extends Equatable { final String rawValue; final Map<String, String> parsedFields; final String? photoPath; ScannedIdData({required this.rawValue, this.parsedFields = const {}, this.photoPath}); ScannedIdData copyWith({String? photoPath}); }`
  - `abstract class ScannerRepository { Stream<String> get detections; Future<void> start(); Future<void> stop(); Future<void> toggleTorch(); bool get isTorchOn; }`
  - `abstract class CameraRepository { Future<String?> capturePhoto(); }`
  - `class CapturePhoto { final CameraRepository repository; CapturePhoto(this.repository); Future<String?> call(); }`

- [ ] **Step 1: Create the entity**

`lib/features/qr_scanner/domain/entities/scanned_id_data.dart`:
```dart
import 'package:equatable/equatable.dart';

/// Data produced by a single successful QR scan, plus anything captured
/// afterwards in the same session (e.g. a verification photo).
class ScannedIdData extends Equatable {
  const ScannedIdData({
    required this.rawValue,
    this.parsedFields = const {},
    this.photoPath,
  });

  /// The raw string payload decoded from the QR code.
  final String rawValue;

  /// Best-effort key/value parse of [rawValue] (empty if it isn't
  /// structured data). Presentation decides how to render this.
  final Map<String, String> parsedFields;

  /// Local file path of a photo captured after the scan, if any.
  final String? photoPath;

  ScannedIdData copyWith({String? photoPath}) {
    return ScannedIdData(
      rawValue: rawValue,
      parsedFields: parsedFields,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  @override
  List<Object?> get props => [rawValue, parsedFields, photoPath];
}
```

- [ ] **Step 2: Create the scanner repository contract**

`lib/features/qr_scanner/domain/repositories/scanner_repository.dart`:
```dart
/// Abstraction over a QR/barcode scanning source. Implemented in the data
/// layer; domain and presentation only ever see this interface.
abstract class ScannerRepository {
  /// Emits the raw string value of each detected code while scanning is
  /// active.
  Stream<String> get detections;

  /// Whether the torch is currently on.
  bool get isTorchOn;

  /// Starts (or resumes) the camera and detection stream.
  Future<void> start();

  /// Stops the camera and detection stream.
  Future<void> stop();

  /// Toggles the torch/flash. Throws if the device has no torch.
  Future<void> toggleTorch();

  /// Releases underlying camera resources. Call when the repository is no
  /// longer needed.
  Future<void> dispose();
}
```

- [ ] **Step 3: Create the camera repository contract**

`lib/features/qr_scanner/domain/repositories/camera_repository.dart`:
```dart
/// Abstraction over capturing a single photo with the device camera.
abstract class CameraRepository {
  /// Opens the camera for a single capture and returns the local file path
  /// of the resulting image, or `null` if the user cancelled.
  Future<String?> capturePhoto();
}
```

- [ ] **Step 4: Create the CapturePhoto usecase**

`lib/features/qr_scanner/domain/usecases/capture_photo.dart`:
```dart
import '../repositories/camera_repository.dart';

/// Captures a single photo via [CameraRepository] and returns its local
/// path, or `null` if the user cancelled the capture.
class CapturePhoto {
  CapturePhoto(this.repository);

  final CameraRepository repository;

  Future<String?> call() => repository.capturePhoto();
}
```

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: no errors. (`lib/features/qr_scanner/domain/**` must not import `package:flutter/*`, `package:mobile_scanner/*`, or `package:image_picker/*` — confirm by inspecting the four files' imports.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/qr_scanner/domain
git commit -m "feat: add qr_scanner domain layer (entity, repositories, usecase)"
```

---

### Task 3: Data layer — datasources and repository implementations

**Files:**
- Create: `lib/features/qr_scanner/data/datasources/mobile_scanner_datasource.dart`
- Create: `lib/features/qr_scanner/data/datasources/image_picker_datasource.dart`
- Create: `lib/features/qr_scanner/data/repositories/scanner_repository_impl.dart`
- Create: `lib/features/qr_scanner/data/repositories/camera_repository_impl.dart`

**Interfaces:**
- Consumes: `ScannerRepository`, `CameraRepository` from Task 2 (`lib/features/qr_scanner/domain/repositories/*`).
- Produces:
  - `class MobileScannerDatasource { MobileScannerDatasource() : controller = MobileScannerController(); final MobileScannerController controller; Stream<String> get detections; bool get isTorchOn; Future<void> start(); Future<void> stop(); Future<void> toggleTorch(); Future<void> dispose(); }`
  - `class ImagePickerDatasource { Future<String?> pickFromCamera(); }`
  - `class ScannerRepositoryImpl implements ScannerRepository { ScannerRepositoryImpl(this._datasource); final MobileScannerDatasource _datasource; }`
  - `class CameraRepositoryImpl implements CameraRepository { CameraRepositoryImpl(this._datasource); final ImagePickerDatasource _datasource; }`

- [ ] **Step 1: Create the mobile_scanner datasource**

`lib/features/qr_scanner/data/datasources/mobile_scanner_datasource.dart`:
```dart
import 'package:mobile_scanner/mobile_scanner.dart';

/// Thin wrapper around [MobileScannerController] — the only place in this
/// feature that talks to the `mobile_scanner` plugin directly.
class MobileScannerDatasource {
  MobileScannerDatasource() : controller = MobileScannerController();

  final MobileScannerController controller;

  bool get isTorchOn => controller.torchEnabled;

  /// Emits the raw value of each barcode detected while scanning.
  Stream<String> get detections {
    return controller.barcodes
        .map((capture) => capture.barcodes)
        .expand((barcodes) => barcodes)
        .map((barcode) => barcode.rawValue)
        .where((value) => value != null)
        .cast<String>();
  }

  Future<void> start() => controller.start();

  Future<void> stop() => controller.stop();

  Future<void> toggleTorch() => controller.toggleTorch();

  Future<void> dispose() => controller.dispose();
}
```

- [ ] **Step 2: Create the image_picker datasource**

`lib/features/qr_scanner/data/datasources/image_picker_datasource.dart`:
```dart
import 'package:image_picker/image_picker.dart';

/// Thin wrapper around [ImagePicker] — the only place in this feature that
/// talks to the `image_picker` plugin directly.
class ImagePickerDatasource {
  ImagePickerDatasource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Opens the device camera for a single photo. Returns the local file
  /// path, or `null` if the user cancelled.
  Future<String?> pickFromCamera() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera);
    return file?.path;
  }
}
```

- [ ] **Step 3: Implement ScannerRepository**

`lib/features/qr_scanner/data/repositories/scanner_repository_impl.dart`:
```dart
import '../../domain/repositories/scanner_repository.dart';
import '../datasources/mobile_scanner_datasource.dart';

class ScannerRepositoryImpl implements ScannerRepository {
  ScannerRepositoryImpl(this._datasource);

  final MobileScannerDatasource _datasource;

  @override
  Stream<String> get detections => _datasource.detections;

  @override
  bool get isTorchOn => _datasource.isTorchOn;

  @override
  Future<void> start() => _datasource.start();

  @override
  Future<void> stop() => _datasource.stop();

  @override
  Future<void> toggleTorch() => _datasource.toggleTorch();

  @override
  Future<void> dispose() => _datasource.dispose();
}
```

- [ ] **Step 4: Implement CameraRepository**

`lib/features/qr_scanner/data/repositories/camera_repository_impl.dart`:
```dart
import '../../domain/repositories/camera_repository.dart';
import '../datasources/image_picker_datasource.dart';

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl(this._datasource);

  final ImagePickerDatasource _datasource;

  @override
  Future<String?> capturePhoto() => _datasource.pickFromCamera();
}
```

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/qr_scanner/data
git commit -m "feat: add qr_scanner data layer (mobile_scanner + image_picker)"
```

---

### Task 4: Presentation — ScannerBloc

**Files:**
- Create: `lib/features/qr_scanner/presentation/bloc/scanner_event.dart`
- Create: `lib/features/qr_scanner/presentation/bloc/scanner_state.dart`
- Create: `lib/features/qr_scanner/presentation/bloc/scanner_bloc.dart`

**Interfaces:**
- Consumes: `ScannerRepository` from Task 2/3 (`start()`, `stop()`, `toggleTorch()`, `isTorchOn`, `detections`).
- Produces:
  - Events: `StartScan`, `CodeDetected(String rawValue)`, `ToggleTorch`, `RetryScan`.
  - States: `ScannerInitial`, `ScannerScanning(bool torchOn)`, `ScannerDetected(String rawValue)`, `ScannerError(String message)`.
  - `class ScannerBloc extends Bloc<ScannerEvent, ScannerState> { ScannerBloc(this._repository) : super(const ScannerInitial()); final ScannerRepository _repository; }`

- [ ] **Step 1: Define events**

`lib/features/qr_scanner/presentation/bloc/scanner_event.dart`:
```dart
import 'package:equatable/equatable.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

/// Starts (or resumes) the camera and scanning.
class StartScan extends ScannerEvent {
  const StartScan();
}

/// Fired internally when the repository's detection stream emits a code.
class CodeDetected extends ScannerEvent {
  const CodeDetected(this.rawValue);

  final String rawValue;

  @override
  List<Object?> get props => [rawValue];
}

/// Toggles the torch/flash.
class ToggleTorch extends ScannerEvent {
  const ToggleTorch();
}

/// Retries starting the scanner after an error.
class RetryScan extends ScannerEvent {
  const RetryScan();
}
```

- [ ] **Step 2: Define states**

`lib/features/qr_scanner/presentation/bloc/scanner_state.dart`:
```dart
import 'package:equatable/equatable.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {
  const ScannerInitial();
}

class ScannerScanning extends ScannerState {
  const ScannerScanning({required this.torchOn});

  final bool torchOn;

  @override
  List<Object?> get props => [torchOn];
}

class ScannerDetected extends ScannerState {
  const ScannerDetected(this.rawValue);

  final String rawValue;

  @override
  List<Object?> get props => [rawValue];
}

class ScannerError extends ScannerState {
  const ScannerError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Implement the bloc**

`lib/features/qr_scanner/presentation/bloc/scanner_bloc.dart`:
```dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/scanner_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc(this._repository) : super(const ScannerInitial()) {
    on<StartScan>(_onStartScan);
    on<CodeDetected>(_onCodeDetected);
    on<ToggleTorch>(_onToggleTorch);
    on<RetryScan>(_onStartScan);
  }

  final ScannerRepository _repository;
  StreamSubscription<String>? _subscription;

  Future<void> _onStartScan(ScannerEvent event, Emitter<ScannerState> emit) async {
    try {
      await _subscription?.cancel();
      await _repository.start();
      _subscription = _repository.detections.listen((rawValue) => add(CodeDetected(rawValue)));
      emit(ScannerScanning(torchOn: _repository.isTorchOn));
    } catch (e) {
      emit(ScannerError('Could not start the camera: $e'));
    }
  }

  Future<void> _onCodeDetected(CodeDetected event, Emitter<ScannerState> emit) async {
    if (state is! ScannerScanning) return;
    await _subscription?.cancel();
    await _repository.stop();
    emit(ScannerDetected(event.rawValue));
  }

  Future<void> _onToggleTorch(ToggleTorch event, Emitter<ScannerState> emit) async {
    if (state is! ScannerScanning) return;
    try {
      await _repository.toggleTorch();
      emit(ScannerScanning(torchOn: _repository.isTorchOn));
    } catch (e) {
      emit(ScannerError('Could not toggle torch: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _repository.dispose();
    return super.close();
  }
}
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/qr_scanner/presentation/bloc/scanner_event.dart lib/features/qr_scanner/presentation/bloc/scanner_state.dart lib/features/qr_scanner/presentation/bloc/scanner_bloc.dart
git commit -m "feat: add ScannerBloc"
```

---

### Task 5: Presentation — CaptureBloc

**Files:**
- Create: `lib/features/qr_scanner/presentation/bloc/capture_event.dart`
- Create: `lib/features/qr_scanner/presentation/bloc/capture_state.dart`
- Create: `lib/features/qr_scanner/presentation/bloc/capture_bloc.dart`

**Interfaces:**
- Consumes: `CapturePhoto` usecase from Task 2 (`Future<String?> call()`).
- Produces:
  - Events: `RequestCapture`.
  - States: `CaptureInitial`, `CaptureInProgress`, `CaptureSuccess(String path)`, `CaptureFailure(String message)`.
  - `class CaptureBloc extends Bloc<CaptureEvent, CaptureState> { CaptureBloc(this._capturePhoto) : super(const CaptureInitial()); final CapturePhoto _capturePhoto; }`

- [ ] **Step 1: Define events**

`lib/features/qr_scanner/presentation/bloc/capture_event.dart`:
```dart
import 'package:equatable/equatable.dart';

abstract class CaptureEvent extends Equatable {
  const CaptureEvent();

  @override
  List<Object?> get props => [];
}

/// Requests opening the camera to capture a verification photo.
class RequestCapture extends CaptureEvent {
  const RequestCapture();
}
```

- [ ] **Step 2: Define states**

`lib/features/qr_scanner/presentation/bloc/capture_state.dart`:
```dart
import 'package:equatable/equatable.dart';

abstract class CaptureState extends Equatable {
  const CaptureState();

  @override
  List<Object?> get props => [];
}

class CaptureInitial extends CaptureState {
  const CaptureInitial();
}

class CaptureInProgress extends CaptureState {
  const CaptureInProgress();
}

class CaptureSuccess extends CaptureState {
  const CaptureSuccess(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

class CaptureFailure extends CaptureState {
  const CaptureFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Implement the bloc**

`lib/features/qr_scanner/presentation/bloc/capture_bloc.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/capture_photo.dart';
import 'capture_event.dart';
import 'capture_state.dart';

class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  CaptureBloc(this._capturePhoto) : super(const CaptureInitial()) {
    on<RequestCapture>(_onRequestCapture);
  }

  final CapturePhoto _capturePhoto;

  Future<void> _onRequestCapture(RequestCapture event, Emitter<CaptureState> emit) async {
    emit(const CaptureInProgress());
    try {
      final path = await _capturePhoto();
      if (path == null) {
        // User cancelled — silently return to the pre-capture state.
        emit(const CaptureInitial());
      } else {
        emit(CaptureSuccess(path));
      }
    } catch (e) {
      emit(CaptureFailure('Could not capture photo: $e'));
    }
  }
}
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/qr_scanner/presentation/bloc/capture_event.dart lib/features/qr_scanner/presentation/bloc/capture_state.dart lib/features/qr_scanner/presentation/bloc/capture_bloc.dart
git commit -m "feat: add CaptureBloc"
```

---

### Task 6: Presentation — shared widgets (ScannerOverlay, InfoBanner)

**Files:**
- Create: `lib/features/qr_scanner/presentation/widgets/scanner_overlay.dart`
- Create: `lib/features/qr_scanner/presentation/widgets/info_banner.dart`

**Interfaces:**
- Produces:
  - `class ScannerOverlay extends StatelessWidget { const ScannerOverlay({super.key}); }` — renders the rounded-square corner-bracket frame.
  - `class InfoBanner extends StatelessWidget { const InfoBanner({super.key, required this.icon, required this.child, this.trailing}); final IconData icon; final Widget child; final Widget? trailing; }` — pill-shaped translucent banner used for the top title bar and bottom hint bar.

- [ ] **Step 1: Create InfoBanner**

`lib/features/qr_scanner/presentation/widgets/info_banner.dart`:
```dart
import 'package:flutter/material.dart';

/// Translucent rounded banner used for the scanner's top title bar and
/// bottom hint bar, matching the reference design.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.child, this.trailing});

  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: DefaultTextStyle(style: const TextStyle(color: Colors.white), child: child)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create ScannerOverlay**

`lib/features/qr_scanner/presentation/widgets/scanner_overlay.dart`:
```dart
import 'package:flutter/material.dart';

/// Rounded-square frame with corner brackets, drawn over the camera
/// preview to show the user where to align the QR code.
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: CustomPaint(painter: _CornerBracketsPainter()),
        ),
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  static const double _bracketLength = 28;
  static const double _inset = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void bracket(Offset corner, Offset dx, Offset dy) {
      canvas.drawLine(corner, corner + dx, paint);
      canvas.drawLine(corner, corner + dy, paint);
    }

    final w = size.width;
    final h = size.height;

    bracket(
      Offset(_inset, _inset),
      const Offset(_bracketLength, 0),
      const Offset(0, _bracketLength),
    );
    bracket(
      Offset(w - _inset, _inset),
      const Offset(-_bracketLength, 0),
      const Offset(0, _bracketLength),
    );
    bracket(
      Offset(_inset, h - _inset),
      const Offset(_bracketLength, 0),
      const Offset(0, -_bracketLength),
    );
    bracket(
      Offset(w - _inset, h - _inset),
      const Offset(-_bracketLength, 0),
      const Offset(0, -_bracketLength),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/qr_scanner/presentation/widgets
git commit -m "feat: add ScannerOverlay and InfoBanner widgets"
```

---

### Task 7: Presentation — ScannerPage

**Files:**
- Create: `lib/features/qr_scanner/presentation/pages/scanner_page.dart`

**Interfaces:**
- Consumes: `ScannerBloc` (Task 4), `MobileScannerDatasource.controller` (Task 3, via `RepositoryProvider`/context read — see note below), `ScannerOverlay`, `InfoBanner` (Task 6), `ResultPage` (Task 8, referenced by route only — created next task; add the navigation call now, file will exist by the time the app runs).
- Produces: `class ScannerPage extends StatelessWidget { const ScannerPage({super.key}); }`

Note on the camera preview widget: `MobileScanner` (the widget, from `package:mobile_scanner`) needs the same `MobileScannerController` instance the bloc/repository/datasource use, so the preview and the detection stream stay in sync. Expose the controller by having `ScannerPage` read the `MobileScannerDatasource` via `RepositoryProvider<MobileScannerDatasource>` (wired in Task 9) rather than constructing its own.

- [ ] **Step 1: Implement ScannerPage**

`lib/features/qr_scanner/presentation/pages/scanner_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/datasources/mobile_scanner_datasource.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../widgets/info_banner.dart';
import '../widgets/scanner_overlay.dart';
import 'result_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  @override
  void initState() {
    super.initState();
    context.read<ScannerBloc>().add(const StartScan());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MobileScannerDatasource>().controller;

    return Scaffold(
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state is ScannerDetected) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ResultPage(rawValue: state.rawValue)),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: controller),
              const ScannerOverlay(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: InfoBanner(
                    icon: Icons.qr_code_scanner,
                    child: const Text('Scan QR to Fetch ID', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: InfoBanner(
                      icon: Icons.info_outline,
                      trailing: state is ScannerScanning
                          ? IconButton(
                              icon: Icon(state.torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                              onPressed: () => context.read<ScannerBloc>().add(const ToggleTorch()),
                            )
                          : null,
                      child: const Text(
                        'Align the QR within the frame. After scan, you can capture a verification photo.',
                      ),
                    ),
                  ),
                ),
              ),
              if (state is ScannerError)
                Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => context.read<ScannerBloc>().add(const RetryScan()),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

`ResultPage` doesn't exist yet (Task 8), so `flutter analyze` will report an unresolved import/type here — that's expected at this point. Run `flutter analyze` and confirm the *only* errors reported are about `result_page.dart` / `ResultPage` being undefined; there should be no other errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/qr_scanner/presentation/pages/scanner_page.dart
git commit -m "feat: add ScannerPage"
```

---

### Task 8: Presentation — ResultPage

**Files:**
- Create: `lib/features/qr_scanner/presentation/pages/result_page.dart`

**Interfaces:**
- Consumes: `CaptureBloc` (Task 5), `ScannedIdData` parsing is done inline in this page (see Step 1).
- Produces: `class ResultPage extends StatelessWidget { const ResultPage({super.key, required this.rawValue}); final String rawValue; }`

- [ ] **Step 1: Implement ResultPage**

`lib/features/qr_scanner/presentation/pages/result_page.dart`:
```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/capture_bloc.dart';
import '../bloc/capture_event.dart';
import '../bloc/capture_state.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.rawValue});

  final String rawValue;

  /// Best-effort parse of `key: value` or `key=value` lines. Returns an
  /// empty map if the value doesn't look like structured data.
  Map<String, String> _parseFields(String value) {
    final lines = value.split(RegExp(r'[\n;]'));
    final fields = <String, String>{};
    for (final line in lines) {
      final match = RegExp(r'^\s*([\w .-]+)\s*[:=]\s*(.+)\s*$').firstMatch(line);
      if (match != null) {
        fields[match.group(1)!.trim()] = match.group(2)!.trim();
      }
    }
    return fields.length >= 2 ? fields : {};
  }

  @override
  Widget build(BuildContext context) {
    final fields = _parseFields(rawValue);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: fields.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in fields.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('${entry.key}: ${entry.value}'),
                              ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(rawValue, style: const TextStyle(fontFamily: 'monospace')),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              BlocConsumer<CaptureBloc, CaptureState>(
                listener: (context, state) {
                  if (state is CaptureFailure) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(state.message)));
                  }
                },
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state is CaptureSuccess)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(state.path), height: 160, fit: BoxFit.cover),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: state is CaptureInProgress
                            ? null
                            : () => context.read<CaptureBloc>().add(const RequestCapture()),
                        icon: state is CaptureInProgress
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                        label: const Text('Capture Photo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no errors (the `ResultPage` import unblocks `scanner_page.dart` too).

- [ ] **Step 3: Commit**

```bash
git add lib/features/qr_scanner/presentation/pages/result_page.dart
git commit -m "feat: add ResultPage"
```

---

### Task 9: Wire everything up in main.dart

**Files:**
- Modify: `lib/main.dart` (full replacement of the default counter app)

**Interfaces:**
- Consumes: `MobileScannerDatasource`, `ImagePickerDatasource`, `ScannerRepositoryImpl`, `CameraRepositoryImpl` (Task 3), `CapturePhoto` (Task 2), `ScannerBloc`, `CaptureBloc` (Tasks 4–5), `ScannerPage` (Task 7).

- [ ] **Step 1: Replace lib/main.dart**

```dart
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
```

Note: `ScannerRepositoryImpl.dispose()` (called from `ScannerBloc.close()`) and the `RepositoryProvider`'s `dispose` callback both end up calling `MobileScannerDatasource.dispose()` → `MobileScannerController.dispose()`. `MobileScannerController.dispose()` is safe to call once the controller is already disposed in current `mobile_scanner` versions (it becomes a no-op), so this double-dispose is not a bug; if `flutter analyze`/runtime later flags it as a problem, remove the `dispose` callback from `RepositoryProvider` and keep only the bloc's.

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no errors, no warnings about the old counter app (it's fully replaced).

- [ ] **Step 3: Manual run check**

Run: `flutter run` on a connected Android device/emulator (skip if none available in this environment — note that in the summary instead of failing the task).
Expected: app launches directly into the QR scanner camera view matching the reference screenshot (top banner, corner-bracket frame, bottom hint banner with torch toggle). Scanning a QR code navigates to the result screen; "Capture Photo" opens the camera and shows a thumbnail; "Scan Again" returns to the scanner.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up qr_scanner feature as app entry point"
```

---

## Post-plan checklist

- [ ] `flutter analyze` is clean across the whole project.
- [ ] `domain/` files contain no `package:flutter`, `package:mobile_scanner`, or `package:image_picker` imports (grep to confirm).
- [ ] `presentation/` files never import anything under `data/datasources/` directly except `scanner_page.dart`'s controlled use of `MobileScannerDatasource` for the preview widget (documented exception in Task 7).
- [ ] App launches to the scanner screen (manual check, Task 9 Step 3).
