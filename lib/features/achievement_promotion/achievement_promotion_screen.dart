import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../phase5/phase5_models.dart';
import '../phase5/phase5_providers.dart';
import 'achievement_promotion_preview_screen.dart';

/// Publisher destinations offered at publish time (Phase 1). Facebook/Instagram
/// are selectable but recorded as pending-connection until Phase 2 (Meta).
const _publishDestinations = <String, String>{
  'parent_app': 'Parent App',
  'student_app': 'Student App',
  'teacher_app': 'Teacher App',
  'staff_app': 'Staff App',
  'whatsapp': 'WhatsApp',
  'website': 'School Website',
  'facebook': 'Facebook',
  'instagram': 'Instagram',
};

Future<List<String>?> _pickDestinations(BuildContext context) {
  final selected = <String>{'parent_app', 'student_app', 'teacher_app', 'staff_app'};
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Select publish destinations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _publishDestinations.entries)
                CheckboxListTile(
                  dense: true,
                  title: Text(entry.value),
                  value: selected.contains(entry.key),
                  onChanged: (v) => setState(() {
                    v == true ? selected.add(entry.key) : selected.remove(entry.key);
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: selected.isEmpty ? null : () => Navigator.pop(context, selected.toList()),
            child: const Text('Publish'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _advanceWorkflow(BuildContext context, WidgetRef ref, AchievementPromotion p) async {
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
    final destinations = await _pickDestinations(context);
    if (destinations == null || destinations.isEmpty) return;
    await ref.read(achievementPromotionRepositoryProvider).publishPromotion(
          query: ref.read(phase5QueryProvider),
          promotionId: p.id,
          destinations: destinations,
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
                    await _advanceWorkflow(context, ref, p);
                    ref.invalidate(achievementPromotionsProvider);
                  },
                  onLongPress: () async {
                    await _advanceWorkflow(context, ref, p);
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
