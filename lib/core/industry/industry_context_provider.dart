import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dynamic_widgets/dynamic_widget_providers.dart';
import '../../features/platform/organization_builder/organization_builder_models.dart';
import '../../features/platform/organization_builder/organization_builder_providers.dart';
import 'industry_type.dart';

/// Manual override for active industry (takes precedence over org profile).
final industryOverrideProvider = StateProvider<IndustryType?>((ref) => null);

/// Reads vertical pack from organization builder mock profile when available.
final organizationBuilderActiveVerticalPackProvider =
    Provider<VerticalPackType?>((ref) {
  final drafts = ref.watch(interviewDraftsProvider).valueOrNull;
  final packs = ref.watch(verticalPacksProvider).valueOrNull;
  if (drafts == null || packs == null || drafts.isEmpty) return null;
  final packId = drafts.first.packId;
  for (final pack in packs) {
    if (pack.id == packId) return pack.type;
  }
  return null;
});

/// Resolves active industry from org builder profile or override.
final activeIndustryProvider = Provider<IndustryType>((ref) {
  final override = ref.watch(industryOverrideProvider);
  if (override != null) return override;

  final packType = ref.watch(organizationBuilderActiveVerticalPackProvider);
  if (packType != null) return _industryFromVerticalPack(packType);
  return IndustryType.school;
});

IndustryType _industryFromVerticalPack(VerticalPackType pack) => switch (pack) {
      VerticalPackType.school => IndustryType.school,
      VerticalPackType.salon => IndustryType.salon,
      VerticalPackType.hospital => IndustryType.hospital,
      VerticalPackType.restaurant => IndustryType.restaurant,
    };

/// Syncs dynamic widget vertical pack when industry changes.
final industryDynamicPackSyncProvider = Provider<void>((ref) {
  ref.watch(activeIndustryProvider);
  ref.listen(activeIndustryProvider, (previous, next) {
    ref.read(dynamicWidgetVerticalPackProvider.notifier).state = next.value;
  });
  final industry = ref.read(activeIndustryProvider);
  ref.read(dynamicWidgetVerticalPackProvider.notifier).state = industry.value;
});
