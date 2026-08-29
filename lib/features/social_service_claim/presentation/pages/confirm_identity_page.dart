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

  static String _initials(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final letters = words.where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final application = context.select((ClaimBloc bloc) => bloc.state.application);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fullName = application?.applicantFullName ?? '';

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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              _initials(fullName),
                              style: textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Application #${application?.applicationNumber ?? ''}',
                                  style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fullName,
                                  style: textTheme.titleLarge,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.groups_outlined, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text('Beneficiary', style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        application?.beneficiaryName ?? '',
                        style: textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 36, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Confirm that the person physically present matches this record before proceeding.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  context.read<ClaimBloc>().add(const IdentityConfirmed());
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaptureIdPage()));
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm this is the claimant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
