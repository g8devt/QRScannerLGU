import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/claim_captures.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'preview_page.dart';
import 'sign_signature_page.dart';

class _CaptureStep {
  const _CaptureStep(this.label, this.getPath, this.withPath, {this.isSignature = false, this.isOptional = false});

  final String label;
  final String? Function(ClaimCaptures) getPath;
  final ClaimCaptures Function(ClaimCaptures, String) withPath;

  /// When true, this step lets the user either photograph a physical
  /// signature or draw one on-screen, instead of only using the camera.
  final bool isSignature;

  /// When true, this capture isn't required to enable Continue/submit.
  final bool isOptional;
}

final List<_CaptureStep> _steps = [
  _CaptureStep('ID Front', (c) => c.idFrontPath, (c, p) => c.copyWith(idFrontPath: p)),
  _CaptureStep('ID Back', (c) => c.idBackPath, (c, p) => c.copyWith(idBackPath: p), isOptional: true),
  _CaptureStep('Signature', (c) => c.signaturePath, (c, p) => c.copyWith(signaturePath: p), isSignature: true),
  _CaptureStep("Claimant's Face Photo", (c) => c.facePhotoPath, (c, p) => c.copyWith(facePhotoPath: p)),
];

/// A single page listing all 4 live captures (ID front, ID back, signature,
/// claimant's face photo) as independent sections — each can be captured or
/// retaken in any order. Reuses [CapturePhoto] from the qr_scanner feature's
/// domain layer — no duplicated camera-capture logic.
class CaptureIdPage extends StatefulWidget {
  const CaptureIdPage({super.key});

  @override
  State<CaptureIdPage> createState() => _CaptureIdPageState();
}

class _CaptureIdPageState extends State<CaptureIdPage> {
  int? _capturingIndex;

  Future<void> _captureWithCamera(int index) async {
    setState(() => _capturingIndex = index);
    try {
      final capturePhoto = context.read<CapturePhoto>();
      final path = await capturePhoto();
      if (!mounted) return;
      if (path == null) return; // cancelled
      _onCaptured(index, path);
    } finally {
      if (mounted) setState(() => _capturingIndex = null);
    }
  }

  Future<void> _signDigitally(int index) async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SignSignaturePage()),
    );
    if (!mounted) return;
    if (path == null) return; // cancelled
    _onCaptured(index, path);
  }

  void _onCaptured(int index, String path) {
    final bloc = context.read<ClaimBloc>();
    final updated = _steps[index].withPath(bloc.state.captures, path);
    bloc.add(CapturesUpdated(updated));
  }

  void _continue() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreviewPage()));
  }

  @override
  Widget build(BuildContext context) {
    final captures = context.select((ClaimBloc bloc) => bloc.state.captures);
    final doneCount = _steps.where((s) => s.getPath(captures) != null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Documents')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressHeader(done: doneCount, total: _steps.length),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _steps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  final path = step.getPath(captures);
                  final capturing = _capturingIndex == index;

                  return _CaptureStepCard(
                    step: step,
                    path: path,
                    capturing: capturing,
                    onCapture: () => _captureWithCamera(index),
                    onSignDigitally: step.isSignature ? () => _signDigitally(index) : null,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: captures.isComplete ? _continue : null,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "N of M captured" line above the list, giving the wizard step a sense of
/// overall progress instead of only per-card feedback.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(Icons.photo_camera_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$done of $total documents captured',
            style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One capture step rendered as a card: label + optional badge, a
/// camera-frame preview (or captured thumbnail with a success check), and
/// the action button(s) for that step.
class _CaptureStepCard extends StatelessWidget {
  const _CaptureStepCard({
    required this.step,
    required this.path,
    required this.capturing,
    required this.onCapture,
    required this.onSignDigitally,
  });

  final _CaptureStep step;
  final String? path;
  final bool capturing;
  final VoidCallback onCapture;
  final VoidCallback? onSignDigitally;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final isCaptured = path != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(step.label, style: textTheme.titleSmall),
                ),
                if (step.isOptional && !isCaptured)
                  _Badge(label: 'Optional', background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant)
                else if (isCaptured)
                  _Badge(label: 'Captured', background: status.successContainer, foreground: status.onSuccessContainer),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: isCaptured
                        ? Image.file(File(path!), fit: BoxFit.cover)
                        : _CaptureFrame(icon: step.isSignature ? Icons.draw_outlined : Icons.badge_outlined),
                  ),
                  if (isCaptured)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: status.success,
                        child: Icon(Icons.check, size: 14, color: status.onSuccess),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (step.isSignature)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: capturing ? null : onCapture,
                      icon: capturing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_outlined),
                      label: Text(isCaptured ? 'Retake' : 'Capture'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: capturing ? null : onSignDigitally,
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Sign Here'),
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: capturing ? null : onCapture,
                icon: capturing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(isCaptured ? 'Retake ${step.label}' : 'Capture ${step.label}'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state camera frame shown before a document is captured — corner
/// guides give the "align inside this box" instruction a visual anchor
/// instead of a bare centered icon.
class _CaptureFrame extends StatelessWidget {
  const _CaptureFrame({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              'No photo yet',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
