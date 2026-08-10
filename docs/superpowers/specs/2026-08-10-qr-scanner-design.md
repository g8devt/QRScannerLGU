# QR Scanner — Design Spec

Date: 2026-08-10
Status: Approved

## Purpose

Build a QR code scanner screen for the Bataan LGU Scanner app, matching the
provided screenshot ("Scan QR to Fetch ID"), structured with pragmatic clean
architecture. No backend/API integration yet — scanning and the post-scan
photo capture are both local-only. This lays groundwork so a real "fetch ID"
API call can be slotted into the `data` layer later without touching
`domain`/`presentation`.

## Scope

- One feature module: `qr_scanner`.
- Android only for now (iOS permissions/config not addressed).
- No networking, no persistence beyond in-memory state for the current scan session.

## Architecture

Pragmatic clean architecture, three layers, no DI package (manual constructor
injection):

```
lib/features/qr_scanner/
  domain/
    entities/
      scanned_id_data.dart      // ScannedIdData { rawValue, parsedFields, photoPath }
    repositories/
      scanner_repository.dart   // abstract: stream of detected codes, start/stop, torch toggle
      camera_repository.dart    // abstract: Future<String?> capturePhoto()
    usecases/
      capture_photo.dart        // CapturePhoto(CameraRepository)
  data/
    datasources/
      mobile_scanner_datasource.dart  // wraps MobileScannerController
      image_picker_datasource.dart    // wraps ImagePicker camera source
    repositories/
      scanner_repository_impl.dart
      camera_repository_impl.dart
  presentation/
    bloc/
      scanner_bloc.dart   // events: StartScan, CodeDetected, ToggleTorch, RetryScan
                            // states: ScannerInitial, ScannerScanning(torchOn), ScannerDetected(data), ScannerError(message)
      capture_bloc.dart   // events: RequestCapture
                            // states: CaptureInitial, CaptureInProgress, CaptureSuccess(path), CaptureFailure(message)
    pages/
      scanner_page.dart
      result_page.dart
    widgets/
      scanner_overlay.dart  // rounded-square frame with corner brackets, matches screenshot
      info_banner.dart      // reusable pill/banner used for top title and bottom hint text
```

Rules:
- `domain` has zero Flutter/plugin imports — pure Dart contracts and entities.
- `data` is the only layer allowed to import `mobile_scanner` / `image_picker`.
- `presentation` depends only on `domain` (usecases/repository interfaces via
  Bloc), never directly on `data`.
- Wiring (constructing datasources → repositories → blocs) happens in
  `main.dart` / a small `injection.dart` helper, using `MultiRepositoryProvider`
  + `MultiBlocProvider`.

## Flow

1. **ScannerPage** (app home) — full-screen `MobileScanner` preview styled per
   the screenshot: top pill banner "Scan QR to Fetch ID", centered
   `ScannerOverlay` (rounded square, corner brackets), bottom info banner with
   hint text and a torch-toggle icon button.
2. `ScannerBloc` subscribes to the scanner datasource's barcode stream. On the
   first successful detection, it pauses the camera stream and emits
   `ScannerDetected(rawValue)`.
3. The page listens for `ScannerDetected` and navigates to **ResultPage**,
   passing the raw scanned string.
4. **ResultPage** attempts to pretty-print the value: if it parses as
   JSON or `key: value` pairs, render as a list; otherwise show the raw
   string in a monospace block. Two actions are shown:
   - **Capture Photo** — dispatches `RequestCapture` to `CaptureBloc`, which
     calls `CapturePhoto` usecase → `CameraRepositoryImpl` (image_picker,
     `ImageSource.camera`). Success shows a thumbnail preview inline;
     cancellation is silent (no error).
   - **Scan Again** — pops back to ScannerPage and resumes the scanner.

## Error handling

- Camera permission denied (scan or capture) → dialog explaining the
  permission is required, with a button to open app settings
  (`AppSettings`/`openAppSettings` via the plugin's built-in handling, or a
  simple `permission_handler`-free retry if the plugin exposes permission
  state directly — implementation detail decided at build time).
- Scanner initialization error (no camera / plugin failure) → `ScannerError`
  state rendered as an inline message + retry button on ScannerPage.
- Photo capture failure (not cancellation) → `CaptureFailure` shown as a
  snackbar on ResultPage; user can retry.

## Dependencies

Add to `pubspec.yaml`:
- `mobile_scanner`
- `flutter_bloc`
- `equatable`
- `image_picker`

Android: add `CAMERA` permission to `android/app/src/main/AndroidManifest.xml`.

## Out of scope (explicitly deferred)

- Any network/API call to fetch ID data from a backend.
- iOS permission/config setup.
- Persisting scan history or captured photos beyond the current session.
- Automated tests (structure is testable — domain has no Flutter deps — but
  writing tests is not part of this pass unless requested separately).
