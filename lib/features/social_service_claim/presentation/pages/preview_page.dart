import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/claimant_info.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import '../bloc/claim_state.dart';
import 'claimant_info_page.dart';
import 'confirm_claim_page.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: SafeArea(
        child: BlocConsumer<ClaimBloc, ClaimState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == ClaimStatus.submitted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ConfirmClaimPage()),
              );
            } else if (state.status == ClaimStatus.submitFailed) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.errorMessage ?? 'Submit failed.')));
            }
          },
          builder: (context, state) {
            final captures = state.captures;
            final claimant = state.claimant;
            final thumbnails = [
              ('ID Front', captures.idFrontPath),
              ('ID Back', captures.idBackPath),
              ('Signature', captures.signaturePath),
              ('Face Photo', captures.facePhotoPath),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Claimant Information', style: Theme.of(context).textTheme.titleMedium),
                          ),
                          IconButton(
                            tooltip: 'Edit claimant information',
                            icon: const Icon(Icons.edit),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ClaimantInfoPage()),
                            ),
                          ),
                        ],
                      ),
                      Text('Claiming as: ${claimant.type == ClaimantType.self ? 'Self' : 'Representative'}'),
                      if (claimant.type == ClaimantType.representative) ...[
                        Text('Representative name: ${claimant.name}'),
                        Text('Relation to applicant: ${claimant.relation}'),
                      ],
                      Text('ID type: ${claimant.idType}'),
                      Text('ID number: ${claimant.idNumber}'),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final (label, path) in thumbnails)
                            Column(
                              children: [
                                Expanded(
                                  child: path != null
                                      ? Image.file(File(path), fit: BoxFit.cover)
                                      : const ColoredBox(color: Colors.black12),
                                ),
                                Text(label),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: state.status == ClaimStatus.submitting
                        ? null
                        : () => context.read<ClaimBloc>().add(ClaimSubmitRequested(
                              usersScannerId: context.read<AuthBloc>().state.user?.id,
                            )),
                    child: state.status == ClaimStatus.submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
