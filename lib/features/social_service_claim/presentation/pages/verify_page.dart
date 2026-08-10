import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import '../bloc/claim_state.dart';
import 'claimant_info_page.dart';
import 'stop_page.dart';

/// First screen after a QR detection: calls verify_qr_bataan and routes to
/// [ClaimantInfoPage] on success or [StopPage] on any rejection.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.rawValue});

  final String rawValue;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  @override
  void initState() {
    super.initState();
    context.read<ClaimBloc>().add(VerifyQrRequested(widget.rawValue));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifying')),
      body: BlocConsumer<ClaimBloc, ClaimState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == ClaimStatus.verifyFailed) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => StopPage(reason: state.errorMessage ?? 'Verification failed.'),
              ),
            );
          } else if (state.status == ClaimStatus.verified) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ClaimantInfoPage()),
            );
          }
        },
        builder: (context, state) {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
