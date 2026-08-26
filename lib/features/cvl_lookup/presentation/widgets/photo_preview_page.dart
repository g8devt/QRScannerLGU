import 'package:flutter/material.dart';

/// Full-screen photo viewer — pinch-to-zoom via [InteractiveViewer].
/// Shared by [CvlPhotoSection] (the read-only detail view) and
/// `_EditablePhotoSection` (the edit form's staged-or-existing photo).
///
/// Dismisses only via the explicit close button, not by tapping the
/// image: [InteractiveViewer] runs its own pan/scale gesture
/// recognizers, which compete with an overlaid GestureDetector's tap
/// recognizer in the same gesture arena — a tap-to-dismiss wrapped
/// around it essentially never wins that arena and stays stuck open.
class PhotoPreviewPage extends StatelessWidget {
  const PhotoPreviewPage({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image(
            image: image,
            // A failed load (bad/unreachable URL, offline device) would
            // otherwise surface as Flutter's default red error box.
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Could not load this photo.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
