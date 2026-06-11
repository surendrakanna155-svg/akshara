import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../phase5/phase5_models.dart';
import '../phase5/phase5_providers.dart';
import 'achievement_promotion_preview_screen.dart';

Future<void> _advanceWorkflow(WidgetRef ref, AchievementPromotion p) async {
  if (p.status == 'draft') {
    await ref.read(achievementPromotionRepositoryProvider).generateAssets(
          query: ref.read(phase5QueryProvider),
          promotionId: p.id,
        );
  } else if (p.status == 'pending_approval') {
    await ref.read(achievementPromotionRepositoryProvider).approvePromotion(
          query: ref.read(phase5QueryProvider),
          promotionId: p.id,
        );
  } else if (p.status == 'approved') {
    await ref.read(achievementPromotionRepositoryProvider).publishPromotion(
          query: ref.read(phase5QueryProvider),
          promotionId: p.id,
        );
  }
}

String _workflowHint(String status) => switch (status) {
      'draft' => 'Tap to generate assets',
      'pending_approval' => 'Tap to approve',
      'approved' => 'Tap to publish',
      'published' => 'Tap to preview assets',
      _ => status,
    };

class AchievementPromotionScreen extends ConsumerWidget {
  const AchievementPromotionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(achievementPromotionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Promotion Center')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(achievementPromotionRepositoryProvider).createPromotion(
                query: ref.read(phase5QueryProvider),
                achievementType: 'competition_winner',
                title: 'New School Achievement',
              );
          ref.invalidate(achievementPromotionsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: promotions.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No promotions yet — create one'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final p = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(p.title),
                  subtitle: Text('${p.achievementType} · ${p.status}\n${_workflowHint(p.status)}'),
                  isThreeLine: true,
                  trailing: Text(
                    '👁 ${p.analytics['views']} · ↗ ${p.analytics['shares']}',
                  ),
                  onTap: () async {
                    if (p.status == 'published' || p.assetPreviews.isNotEmpty) {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AchievementPromotionPreviewScreen(promotion: p),
                        ),
                      );
                      ref.invalidate(achievementPromotionsProvider);
                      return;
                    }
                    await _advanceWorkflow(ref, p);
                    ref.invalidate(achievementPromotionsProvider);
                  },
                  onLongPress: () async {
                    await _advanceWorkflow(ref, p);
                    ref.invalidate(achievementPromotionsProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
