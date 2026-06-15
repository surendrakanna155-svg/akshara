import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import '../../shared/widgets/akshara_manage_action.dart';
import '../phase5/phase5_models.dart';
import '../phase5/phase5_providers.dart';
import 'memories_mutations_provider.dart';
import 'school_memory_media_viewer.dart';

class SchoolMemoryEventScreen extends ConsumerStatefulWidget {
  const SchoolMemoryEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<SchoolMemoryEventScreen> createState() =>
      _SchoolMemoryEventScreenState();
}

class _SchoolMemoryEventScreenState
    extends ConsumerState<SchoolMemoryEventScreen> {
  bool _uploading = false;

  Future<void> _uploadMedia({required bool video}) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final title = video ? 'Uploaded video' : 'Uploaded photo';
      final filename = video
          ? 'clip_${DateTime.now().millisecondsSinceEpoch}.mp4'
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = video ? _mockVideoBytes() : _mockPhotoBytes();
      await ref.read(schoolMemoriesRepositoryProvider).uploadMediaBytes(
            query: ref.read(phase5QueryProvider),
            eventId: widget.eventId,
            bytes: bytes,
            filename: filename,
            title: title,
            albumTitle: 'Mobile uploads',
            mediaType: video ? 'video' : 'photo',
          );
      ref.invalidate(schoolMemoryEventProvider(widget.eventId));
      ref.invalidate(schoolMemoriesEventsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(video ? 'Video uploaded' : 'Photo uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadMedia(SchoolMemoryMedia media) async {
    try {
      final url = media.storageUrl.isNotEmpty
          ? media.storageUrl
          : await ref.read(schoolMemoriesRepositoryProvider).getDownloadUrl(
                query: ref.read(phase5QueryProvider),
                mediaId: media.id,
              );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _shareMedia(SchoolMemoryMedia media) async {
    try {
      final token = media.shareToken;
      if (token == null || token.isEmpty) {
        throw StateError('No share token for this media');
      }
      final link =
          await ref.read(schoolMemoriesRepositoryProvider).resolveShareLink(
                query: ref.read(phase5QueryProvider),
                shareToken: token,
              );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share link ready · event ${link.eventId}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(schoolMemoryEventProvider(widget.eventId));
    final publishing = ref.watch(publishSchoolMemoryEventProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.maybeWhen(
            data: (e) => Text(e.title), orElse: () => const Text('Event')),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              tooltip: 'Upload photo',
              onPressed: () => _uploadMedia(video: false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              tooltip: 'Upload video',
              onPressed: () => _uploadMedia(video: true),
            ),
          ],
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(event.description ?? '',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Chip(label: Text('${event.category} · ${event.status}')),
              if (event.status.toLowerCase() == 'draft') ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AksharaManageAction(
                    permission: Permission.manageSchoolMemories,
                    child: FilledButton.icon(
                      key: QaTestKeys.schoolMemoriesPublishButton,
                      onPressed: publishing
                          ? null
                          : () async {
                              final notifier = ref.read(
                                publishSchoolMemoryEventProvider.notifier,
                              );
                              final result = await notifier.execute(
                                eventId: widget.eventId,
                              );
                              if (!context.mounted || result == null) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  key: QaTestKeys
                                      .schoolMemoriesPublishedSnackbar,
                                  content:
                                      Text('School memory event published.'),
                                ),
                              );
                            },
                      icon: publishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.publish_outlined),
                      label: const Text('Publish event'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (event.albums.isEmpty)
                AksharaEmptyState(
                  message: 'Upload a photo or video to create the first album.',
                  actionLabel: 'Upload photo',
                  onAction: () => _uploadMedia(video: false),
                  compact: true,
                )
              else
                for (final album in event.albums) ...[
                  Text(album.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('${album.mediaCount} items'),
                  const SizedBox(height: 8),
                  if (album.media.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No media in this album yet'),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: album.media.length,
                      itemBuilder: (context, index) {
                        final media = album.media[index];
                        return InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SchoolMemoryMediaViewer(media: media),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  image: !media.isVideo &&
                                          media.storageUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(media.storageUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: media.isVideo
                                    ? const Icon(Icons.play_circle_outline,
                                        size: 36)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'download':
                                        _downloadMedia(media);
                                      case 'share':
                                        _shareMedia(media);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'download',
                                        child: Text('Download')),
                                    PopupMenuItem(
                                        value: 'share',
                                        child: Text('Share link')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],
            ],
          );
        },
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(
          message: 'Could not load event: $e',
          onRetry: () =>
              ref.invalidate(schoolMemoryEventProvider(widget.eventId)),
        ),
      ),
    );
  }

  List<int> _mockPhotoBytes() => Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
      ]);

  List<int> _mockVideoBytes() => Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x18,
        0x66,
        0x74,
        0x79,
        0x70,
        0x6D,
        0x70,
      ]);
}
