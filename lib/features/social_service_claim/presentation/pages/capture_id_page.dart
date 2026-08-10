import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Documents')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _steps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  final path = step.getPath(captures);
                  final capturing = _capturingIndex == index;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        step.isOptional ? '${step.label} (Optional)' : step.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: path != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(path), fit: BoxFit.cover),
                              )
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(child: Icon(Icons.camera_alt, size: 48)),
                              ),
                      ),
                      const SizedBox(height: 8),
                      if (step.isSignature)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: capturing ? null : () => _captureWithCamera(index),
                                icon: capturing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.camera_alt),
                                label: Text(path == null ? 'Capture Signature' : 'Retake'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: capturing ? null : () => _signDigitally(index),
                                icon: const Icon(Icons.draw),
                                label: const Text('Sign Here'),
                              ),
                            ),
                          ],
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: capturing ? null : () => _captureWithCamera(index),
                          icon: capturing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.camera_alt),
                          label: Text(path == null ? 'Capture ${step.label}' : 'Retake'),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: captures.isComplete ? _continue : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
