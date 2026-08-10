import 'dart:io';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Lets the user draw their signature on-screen with a finger/stylus, as an
/// alternative to photographing a physical signature. Returns the local file
/// path of the saved PNG, or `null` if the user cancelled without signing.
class SignSignaturePage extends StatefulWidget {
  const SignSignaturePage({super.key});

  @override
  State<SignSignaturePage> createState() => _SignSignaturePageState();
}

class _SignSignaturePageState extends State<SignSignaturePage> {
  final _controller = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) return;
    setState(() => _saving = true);
    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null) return;
      final path =
          '${Directory.systemTemp.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Here'),
        actions: [
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.clear(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Sign inside the box below'),
              const SizedBox(height: 16),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Signature(controller: _controller, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Use This Signature'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
