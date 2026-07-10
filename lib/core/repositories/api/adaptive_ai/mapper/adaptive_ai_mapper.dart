// Adaptive AI (P3-AI-2 / W2) — DTO → domain-model mapper. Pure translation.

import '../../../../../features/adaptive_ai/adaptive_ai_models.dart';
import '../dto/adaptive_ai_dto.dart';

class AdaptiveAiMapper {
  const AdaptiveAiMapper();

  AdaptiveAction toAction(AdaptiveActionDto dto) => AdaptiveAction(
        label: dto.label,
        deepLink: dto.deepLink,
        payload: dto.payload,
        requiresConfirmation: dto.requiresConfirmation,
      );

  AdaptivePriorityItem toItem(AdaptivePriorityItemDto dto) => AdaptivePriorityItem(
        itemKey: dto.itemKey,
        type: dto.type,
        title: dto.title,
        detail: dto.detail,
        score: dto.score,
        reason: dto.reason,
        action: dto.action == null ? null : toAction(dto.action!),
      );

  AdaptiveFeed toFeed(AdaptiveFeedDto dto) => AdaptiveFeed(
        persona: dto.persona,
        items: dto.items.map(toItem).toList(),
        criticalCount: dto.criticalCount,
        degraded: dto.degraded,
      );

  QuickActionResolver toResolver(QuickActionResolverDto dto) =>
      QuickActionResolver(kind: dto.kind, target: dto.target, prompt: dto.prompt);

  AdaptiveQuickAction toQuickAction(AdaptiveQuickActionDto dto) => AdaptiveQuickAction(
        id: dto.id,
        label: dto.label,
        tier: dto.tier,
        requiresEntity: dto.requiresEntity,
        resolver: toResolver(dto.resolver),
      );

  SearchResultItem toSearchResult(SearchResultItemDto dto) => SearchResultItem(
        category: dto.category,
        id: dto.id,
        title: dto.title,
        subtitle: dto.subtitle,
        deepLink: dto.deepLink,
      );

  SearchGroup toSearchGroup(SearchGroupDto dto) => SearchGroup(
        category: dto.category,
        label: dto.label,
        results: dto.results.map(toSearchResult).toList(),
        total: dto.total,
      );

  UniversalSearchResult toSearchResultSet(UniversalSearchResultDto dto) => UniversalSearchResult(
        query: dto.query,
        groups: dto.groups.map(toSearchGroup).toList(),
      );
}
