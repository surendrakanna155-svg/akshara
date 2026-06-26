import 'package:flutter/material.dart';

import '../phase5/phase5_models.dart';
import '../../theme/spacing.dart';

class SchoolMemoryMediaViewer extends StatelessWidget {
  const SchoolMemoryMediaViewer({super.key, required this.media});

  final SchoolMemoryMedia media;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(media.title)),
      body: Center(
        child: media.isVideo
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam, size: 72),
                  const SizedBox(height: 16),
                  Text('Video · ${media.mediaType}'),
                  if (media.storageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AksharaSpacing.s4),
                      child: Text(media.storageUrl, textAlign: TextAlign.center),
                    ),
                ],
              )
            : media.storageUrl.isNotEmpty
                ? InteractiveViewer(
                    child: Image.network(
                      media.storageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 72),
                    ),
                  )
                : const Icon(Icons.image_outlined, size: 72),
      ),
    );
  }
}
