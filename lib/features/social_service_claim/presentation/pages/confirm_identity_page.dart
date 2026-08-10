import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'capture_id_page.dart';

/// Photo-less manual gate: staff visually matches the physical claimant
/// against the verified application's name/details. No stored reference
/// photo exists to show (neither `photo_2x2` nor `image_verification` is
/// used for this step — see the design spec).
class ConfirmIdentityPage extends StatelessWidget {
  const ConfirmIdentityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final application = context.select((ClaimBloc bloc) => bloc.state.application);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Identity')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Application #${application?.applicationNumber ?? ''}'),
                      const SizedBox(height: 8),
                      Text(
                        application?.applicantFullName ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Beneficiary: ${application?.beneficiaryName ?? ''}'),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Confirm that the person physically present matches this record before proceeding.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<ClaimBloc>().add(const IdentityConfirmed());
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaptureIdPage()));
                },
                child: const Text('Confirm this is the claimant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
