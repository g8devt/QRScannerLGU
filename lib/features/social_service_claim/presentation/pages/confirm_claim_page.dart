import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';

class ConfirmClaimPage extends StatelessWidget {
  const ConfirmClaimPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColors.successContainer,
                    boxShadow: AppTheme.glow(statusColors.success),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: statusColors.onSuccessContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Claim recorded',
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The claim has been submitted successfully.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      context.read<ClaimBloc>().add(const ClaimSessionReset());
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
