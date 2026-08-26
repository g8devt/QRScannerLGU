import 'package:flutter/material.dart';

import '../../domain/entities/cvl_record.dart';
import 'photo_preview_page.dart';

/// Shows the record's photo, read-only — editing/replacing it now lives
/// in `CvlEditPage`, not here. Tapping the thumbnail opens a full-screen,
/// pinch-to-zoom preview ([PhotoPreviewPage]); disabled when there's
/// nothing to show (no [CvlRecord.hasDisplayableImage] — a legacy
/// PHP-admin-uploaded photo is a relative path this app has no session
/// to load).
class CvlPhotoSection extends StatelessWidget {
  const CvlPhotoSection({super.key, required this.record});

  final CvlRecord record;

  void _openFullScreenPreview(BuildContext context) {
    if (!record.hasDisplayableImage) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoPreviewPage(image: NetworkImage(record.imgPath)),
      ),
    );
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
            Center(
              child: GestureDetector(
                onTap: record.hasDisplayableImage
                    ? () => _openFullScreenPreview(context)
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 120,
                    height: 120,
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
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.broken_image_outlined,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          )
                        : Icon(
                            Icons.person_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
