import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';

/// Shows the record's photo (only when [CvlRecord.hasDisplayableImage] —
/// a legacy PHP-admin-uploaded photo is a relative path this app has no
/// session to load) with an "Edit Photo" action that captures a new
/// selfie via the camera and uploads it. Shared by [CvlLookupPage] (the
/// read-only detail view) and [CvlEditPage] (the contact-info edit
/// form) — both sit on the same [CvlLookupCubit].
class CvlPhotoSection extends StatelessWidget {
  const CvlPhotoSection({
    super.key,
    required this.record,
    required this.isUpdatingPhoto,
  });

  final CvlRecord record;
  final bool isUpdatingPhoto;

  Future<void> _editPhoto(BuildContext context) async {
    final cubit = context.read<CvlLookupCubit>();
    final capturePhoto = context.read<CapturePhoto>();
    final username = context.read<AuthBloc>().state.user?.username;

    final path = await capturePhoto();
    if (path == null) return; // user cancelled
    await cubit.updatePhoto(path, updatedBy: username);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: record.hasDisplayableImage
                        ? Image.network(
                            record.imgPath,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          )
                        : Icon(
                            Icons.person_outline,
                            size: 40,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUpdatingPhoto
                        ? null
                        : () => _editPhoto(context),
                    icon: isUpdatingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: Text(isUpdatingPhoto ? 'Uploading...' : 'Edit Photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
