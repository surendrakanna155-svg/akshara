import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../theme/theme_extensions.dart';
import '../phase5/phase5_models.dart';
import '../phase5/phase5_providers.dart';
import '../../theme/spacing.dart';

class AchievementPromotionPreviewScreen extends ConsumerStatefulWidget {
  const AchievementPromotionPreviewScreen({super.key, required this.promotion});

  final AchievementPromotion promotion;

  @override
  ConsumerState<AchievementPromotionPreviewScreen> createState() =>
      _AchievementPromotionPreviewScreenState();
}

class _AchievementPromotionPreviewScreenState
    extends ConsumerState<AchievementPromotionPreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(achievementPromotionRepositoryProvider).trackMetric(
            query: ref.read(phase5QueryProvider),
            promotionId: widget.promotion.id,
            metric: 'views',
          );
    });
  }

  Future<void> _exportMetadata() async {
    final export = {
      'promotionId': widget.promotion.id,
      'title': widget.promotion.title,
      'status': widget.promotion.status,
      'assets': widget.promotion.assetPreviews.map((a) => a.toExportJson()).toList(),
    };
    await Clipboard.setData(ClipboardData(text: export.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metadata copied to clipboard')),
      );
    }
    await ref.read(achievementPromotionRepositoryProvider).trackMetric(
          query: ref.read(phase5QueryProvider),
          promotionId: widget.promotion.id,
          metric: 'downloads',
        );
  }

  Future<void> _shareMetadata() async {
    await ref.read(achievementPromotionRepositoryProvider).trackMetric(
          query: ref.read(phase5QueryProvider),
          promotionId: widget.promotion.id,
          metric: 'shares',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share tracked — image generation deferred')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previews = widget.promotion.assetPreviews;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promotion.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export metadata',
            onPressed: _exportMetadata,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Track share',
            onPressed: _shareMetadata,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text('Status: ${widget.promotion.status}',
              style: context.aksharaText.titleMedium),
          Text(
            'Analytics: ${widget.promotion.analytics['views']} views · '
            '${widget.promotion.analytics['shares']} shares · '
            '${widget.promotion.analytics['downloads']} downloads',
          ),
          if (widget.promotion.status == 'pending_approval')
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const ListTile(
                leading: Icon(Icons.pending_actions),
                title: Text('Awaiting principal approval'),
                subtitle: Text('Approve before publishing to channels'),
              ),
            ),
          const SizedBox(height: 16),
          if (previews.isEmpty)
            const Text('Generate assets to preview promotion metadata.')
          else
            ...previews.map(
              (asset) => Card(
                margin: const EdgeInsets.only(bottom: AksharaSpacing.s3),
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.label, style: context.aksharaText.titleMedium),
                      const SizedBox(height: 8),
                      Text(asset.headline, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(asset.caption),
                      const SizedBox(height: 8),
                      Text('Format: ${asset.format}'),
                      if (asset.width != null && asset.height != null)
                        Text('Size: ${asset.width}×${asset.height} (${asset.aspectRatio ?? ''})'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          asset.previewUrl == null
                              ? 'Image preview (Copilot gen interface ready)'
                              : 'Preview',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stub — wire to Document Engine / Copilot when image generation ships.
class StubPromotionImageGenerator implements PromotionImageGenerator {
  @override
  Future<String?> generatePoster({
    required String title,
    required String headline,
    required String caption,
    required int width,
    required int height,
  }) async =>
      null;
}
