import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../qr_scanner/data/datasources/mobile_scanner_datasource.dart';
import '../../../qr_scanner/presentation/bloc/scanner_bloc.dart';
import '../../../qr_scanner/presentation/bloc/scanner_event.dart';
import '../../../qr_scanner/presentation/bloc/scanner_state.dart';
import '../../../qr_scanner/presentation/widgets/scanner_overlay.dart';
import '../../domain/repositories/cvl_repository.dart';

/// Opens [SetQrSheet] for [fullName], calling [onSetQr] once a scanned
/// code is confirmed, then shows a confirmation snackbar on the current
/// page once it reports success. [onSetQr] should rethrow
/// [CvlLookupException] on rejection (unregistered code, already
/// assigned, already in use) — the sheet catches it and shows the
/// message inline instead of dismissing.
Future<void> openSetQrSheet(
  BuildContext context, {
  required String fullName,
  required Future<void> Function(String qrCode) onSetQr,
}) async {
  final success = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SetQrSheet(fullName: fullName, onSetQr: onSetQr),
  );
  if (success == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('QR code set.')));
  }
}

/// Confirms with the staff member, then calls [onRemoveQr] to unassign
/// the QR code for [fullName]. Shows an error dialog on rejection (e.g.
/// the record has no QR assigned) instead of silently failing.
/// [onRemoveQr] should rethrow [CvlLookupException] on rejection.
Future<void> confirmAndRemoveQr(
  BuildContext context, {
  required String fullName,
  required Future<void> Function() onRemoveQr,
}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Remove QR code?',
    message:
        'This will unassign the QR code from $fullName and free '
        'it for reuse on another record.',
    confirmLabel: 'Remove',
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await onRemoveQr();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('QR code removed.')));
  } on CvlLookupException catch (e) {
    if (!context.mounted) return;
    await showMessageDialog(
      context,
      title: 'Could not remove QR code',
      message: e.message,
    );
  } catch (e) {
    if (!context.mounted) return;
    await showMessageDialog(
      context,
      title: 'Could not remove QR code',
      message: 'Network error — could not reach the server: $e',
    );
  }
}

enum _SetQrPhase { scanning, confirming, validating, success, error }

/// Bottom sheet that scans a QR code with the app's shared camera (via
/// the existing [ScannerBloc]/[MobileScannerDatasource], the same pieces
/// [ScannerPage] uses) and assigns it via [onSetQr]. A freshly-scanned
/// code is confirmed with the staff member before it's sent; a code the
/// backend rejects — unregistered, already assigned to another record,
/// or already in use — surfaces as a dialog, then resumes scanning
/// instead of dismissing the sheet.
class SetQrSheet extends StatefulWidget {
  const SetQrSheet({super.key, required this.fullName, required this.onSetQr});

  final String fullName;
  final Future<void> Function(String qrCode) onSetQr;

  @override
  State<SetQrSheet> createState() => _SetQrSheetState();
}

class _SetQrSheetState extends State<SetQrSheet> {
  _SetQrPhase _phase = _SetQrPhase.scanning;
  String? _errorMessage;

  // Cached here, not looked up in dispose() — an ancestor lookup via
  // context.read() is unsafe once the widget is deactivated, which is
  // exactly what's happening by the time dispose() runs.
  late final ScannerBloc _scannerBloc;

  @override
  void initState() {
    super.initState();
    _scannerBloc = context.read<ScannerBloc>();
    // Deferred to after the first frame, same reasoning as ScannerPage:
    // the MobileScanner platform view needs a completed first layout
    // before starting the camera, or the preview stays blank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scannerBloc.add(const StartScan());
    });
  }

  @override
  void dispose() {
    _scannerBloc.add(const PauseScan());
    super.dispose();
  }

  Future<void> _handleDetected(String rawValue) async {
    setState(() {
      _phase = _SetQrPhase.confirming;
      _errorMessage = null;
    });
    final confirmed = await showConfirmDialog(
      context,
      title: 'Set QR code?',
      message: 'Assign this QR code to ${widget.fullName}?',
      confirmLabel: 'Set',
    );
    if (!mounted) return;
    if (!confirmed) {
      _retry();
      return;
    }

    setState(() => _phase = _SetQrPhase.validating);
    try {
      await widget.onSetQr(rawValue);
      if (!mounted) return;
      setState(() => _phase = _SetQrPhase.success);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop(true);
    } on CvlLookupException catch (e) {
      if (!mounted) return;
      await _showRejectionDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      await _showRejectionDialog('Could not set the QR code: $e');
    }
  }

  /// Shows the backend's rejection reason (unregistered code, already
  /// assigned, already in use) in a dialog, then resumes scanning once
  /// it's dismissed — mirrors the confirm dialog's "stay in the sheet"
  /// behavior rather than closing it outright.
  Future<void> _showRejectionDialog(String message) async {
    await showMessageDialog(
      context,
      title: 'Could not set QR code',
      message: message,
    );
    if (mounted) _retry();
  }

  void _retry() {
    setState(() {
      _phase = _SetQrPhase.scanning;
      _errorMessage = null;
    });
    _scannerBloc.add(const RetryScan());
  }

  String get _subtitle => switch (_phase) {
    _SetQrPhase.scanning => 'Align the QR code within the frame.',
    _SetQrPhase.confirming => 'Confirm to continue…',
    _SetQrPhase.validating => 'Checking the QR code…',
    _SetQrPhase.success => 'QR code set.',
    _SetQrPhase.error => _errorMessage ?? 'Could not set the QR code.',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = context.read<MobileScannerDatasource>().controller;

    return BlocListener<ScannerBloc, ScannerState>(
      listenWhen: (previous, current) =>
          current is ScannerDetected || current is ScannerError,
      listener: (context, state) {
        if (state is ScannerDetected && _phase == _SetQrPhase.scanning) {
          _handleDetected(state.rawValue);
        } else if (state is ScannerError) {
          setState(() {
            _phase = _SetQrPhase.error;
            _errorMessage = state.message;
          });
        }
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Set QR — ${widget.fullName}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _phase == _SetQrPhase.error
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(controller: controller),
                      const ScannerOverlay(),
                      if (_phase == _SetQrPhase.validating)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (_phase == _SetQrPhase.success)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 56,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phase == _SetQrPhase.error)
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                )
              else
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
