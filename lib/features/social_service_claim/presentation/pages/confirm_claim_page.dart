import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';

class ConfirmClaimPage extends StatelessWidget {
  const ConfirmClaimPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 72),
                const SizedBox(height: 16),
                const Text('Claim recorded', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ClaimBloc>().add(const ClaimSessionReset());
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
