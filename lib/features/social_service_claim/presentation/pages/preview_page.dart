import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/info_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../cvl_lookup/presentation/widgets/photo_preview_page.dart';
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
            final claimantRows = <String, String>{
              'Claiming as':
                  claimant.type == ClaimantType.self ? 'Self' : 'Representative',
              if (claimant.type == ClaimantType.representative) ...{
                'Representative name': claimant.name,
                'Relation to applicant': claimant.relation,
              },
              'ID type': claimant.idType,
              'ID number': claimant.idNumber,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Review claim',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confirm the details below before submitting.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          InfoCard(
                            title: 'Claimant Information',
                            rows: claimantRows,
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filledTonal(
                              tooltip: 'Edit claimant information',
                              icon: const Icon(Icons.edit_outlined),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ClaimantInfoPage()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Captured Documents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          for (final (label, path) in thumbnails)
                            _CaptureThumbnail(label: label, path: path),
                        ],
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: FilledButton(
                      onPressed: state.status == ClaimStatus.submitting
                          ? null
                          : () => context.read<ClaimBloc>().add(ClaimSubmitRequested(
                                usersScannerId: context.read<AuthBloc>().state.user?.id,
                              )),
                      child: state.status == ClaimStatus.submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
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

/// One captured-document tile in the review grid — a rounded thumbnail
/// with its label underneath, tappable for a full-screen zoomed view when
/// the file was actually captured, or a considered "not captured" empty
/// state otherwise.
class _CaptureThumbnail extends StatelessWidget {
  const _CaptureThumbnail({required this.label, required this.path});

  final String label;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = path != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: hasPhoto
                ? InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoPreviewPage(
                          image: FileImage(File(path!)),
                        ),
                      ),
                    ),
                    child: Image.file(File(path!), fit: BoxFit.cover),
                  )
                : Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: colorScheme.outline,
                      size: 28,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.labelMedium?.copyWith(
            color: hasPhoto ? null : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
