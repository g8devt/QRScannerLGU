import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/scanned_id_data.dart';
import '../bloc/capture_bloc.dart';
import '../bloc/capture_event.dart';
import '../bloc/capture_state.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.rawValue});

  final String rawValue;

  /// Best-effort parse of `key: value` or `key=value` lines. Returns an
  /// empty map if the value doesn't look like structured data.
  Map<String, String> _parseKeyValueFields(String value) {
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

  /// Parses [value] as JSON first (when it decodes to a map), falling back
  /// to `key:value`/`key=value` line parsing otherwise.
  Map<String, String> _parseFields(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final fields = decoded.map((key, val) => MapEntry(key.toString(), val.toString()));
        if (fields.length >= 2) return fields;
      }
    } catch (_) {
      // Not JSON — fall through to key/value parsing.
    }
    return _parseKeyValueFields(value);
  }

  @override
  Widget build(BuildContext context) {
    final fields = _parseFields(rawValue);
    final data = ScannedIdData(rawValue: rawValue, parsedFields: fields);

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
                  child: data.parsedFields.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in data.parsedFields.entries)
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
                          child: Text(data.rawValue, style: const TextStyle(fontFamily: 'monospace')),
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
