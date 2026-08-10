import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';

/// Terminal screen for any rejection from verify_qr_bataan (not found,
/// already claimed, not yet eligible).
class StopPage extends StatelessWidget {
  const StopPage({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, color: Colors.red.shade700, size: 64),
                const SizedBox(height: 16),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ClaimBloc>().add(const ClaimSessionReset());
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
