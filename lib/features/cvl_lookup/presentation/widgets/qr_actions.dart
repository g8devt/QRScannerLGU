import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_theme.dart';
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Center(child: _SetQrStatusPill(phase: _phase)),
              const SizedBox(height: 6),
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
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    height: 260,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(controller: controller),
                        const ScannerOverlay(),
                        if (_phase == _SetQrPhase.validating)
                          const _ValidatingOverlay(),
                        if (_phase == _SetQrPhase.success)
                          const _SuccessOverlay(),
                      ],
                    ),
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

/// Small pill summarizing [_SetQrPhase] at a glance — mirrors
/// `_QrStatusBadge` on the search page rather than leaving the phase
/// only implied by the longer sentence underneath it.
class _SetQrStatusPill extends StatelessWidget {
  const _SetQrStatusPill({required this.phase});

  final _SetQrPhase phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>()!;
    final (background, foreground, icon, label) = switch (phase) {
      _SetQrPhase.scanning => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.qr_code_scanner_rounded,
        'Scanning',
      ),
      _SetQrPhase.confirming => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.touch_app_rounded,
        'Confirm to continue',
      ),
      _SetQrPhase.validating => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.hourglass_top_rounded,
        'Validating',
      ),
      _SetQrPhase.success => (
        status.successContainer,
        status.onSuccessContainer,
        Icons.check_circle_rounded,
        'QR code set',
      ),
      _SetQrPhase.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
        'Could not set QR code',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrim shown over the camera frame while the scanned code is being
/// validated with the backend — a contained pill instead of a bare
/// spinner floating on a flat scrim.
class _ValidatingOverlay extends StatelessWidget {
  const _ValidatingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Checking…',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrim shown once the QR code has been accepted — the checkmark tint
/// comes from [AppStatusColors.success] rather than a raw
/// `Colors.greenAccent`, in a soft glowing badge instead of a bare icon.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<AppStatusColors>()!;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: status.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: status.success.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.check_rounded, color: status.onSuccess, size: 44),
        ),
      ),
    );
  }
}
