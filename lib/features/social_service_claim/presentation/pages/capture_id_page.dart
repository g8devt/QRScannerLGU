import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/claim_captures.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'preview_page.dart';

class _CaptureStep {
  const _CaptureStep(this.label, this.getPath, this.withPath);

  final String label;
  final String? Function(ClaimCaptures) getPath;
  final ClaimCaptures Function(ClaimCaptures, String) withPath;
}

final List<_CaptureStep> _steps = [
  _CaptureStep('ID Front', (c) => c.idFrontPath, (c, p) => c.copyWith(idFrontPath: p)),
  _CaptureStep('ID Back', (c) => c.idBackPath, (c, p) => c.copyWith(idBackPath: p)),
  _CaptureStep('Signature', (c) => c.signaturePath, (c, p) => c.copyWith(signaturePath: p)),
  _CaptureStep("Claimant's Face Photo", (c) => c.facePhotoPath, (c, p) => c.copyWith(facePhotoPath: p)),
];

/// Four sequential live captures (ID front, ID back, signature, claimant's
/// face photo). Reuses [CapturePhoto] from the qr_scanner feature's domain
/// layer — no duplicated camera-capture logic.
class CaptureIdPage extends StatefulWidget {
  const CaptureIdPage({super.key});

  @override
  State<CaptureIdPage> createState() => _CaptureIdPageState();
}

class _CaptureIdPageState extends State<CaptureIdPage> {
  int _stepIndex = 0;
  bool _capturing = false;

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final capturePhoto = context.read<CapturePhoto>();
      final path = await capturePhoto();
      if (!mounted) return;
      if (path == null) return; // cancelled — stay on this step
      final bloc = context.read<ClaimBloc>();
      final updated = _steps[_stepIndex].withPath(bloc.state.captures, path);
      bloc.add(CapturesUpdated(updated));
      if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex++);
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreviewPage()));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final captures = context.select((ClaimBloc bloc) => bloc.state.captures);
    final path = step.getPath(captures);

    return Scaffold(
      appBar: AppBar(title: Text('Capture: ${step.label}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Step ${_stepIndex + 1} of ${_steps.length}'),
              const SizedBox(height: 16),
              if (path != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                )
              else
                const Expanded(child: Center(child: Icon(Icons.camera_alt, size: 96))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _capturing ? null : _capture,
                icon: _capturing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: Text(path == null ? 'Capture ${step.label}' : 'Retake'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
