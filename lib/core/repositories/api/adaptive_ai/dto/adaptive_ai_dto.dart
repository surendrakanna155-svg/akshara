// Adaptive AI (P3-AI-2 / W2) — DTOs mirroring the backend response shapes for
// /intelligence/{priorities,recommendations,quick-actions} and /search. Pure
// deserialization; the mapper turns these into domain models.

import '../../admissions/dto/api_envelope_dto.dart';

Map<String, dynamic> parseAdaptiveEnvelope(Map<String, dynamic> json) {
  return ApiEnvelopeDto.fromJson(json).data ?? const {};
}

List<Map<String, dynamic>> _items(Map<String, dynamic> data, String key) {
  final raw = data[key];
  if (raw is List) {
    return raw.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _double(dynamic v, [double fallback = 1.0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

String _str(dynamic v, [String fallback = '']) => v is String ? v : fallback;

class AdaptiveActionDto {
  const AdaptiveActionDto({
    required this.label,
    required this.deepLink,
    required this.payload,
    required this.requiresConfirmation,
  });

  factory AdaptiveActionDto.fromJson(Map<String, dynamic> json) {
    return AdaptiveActionDto(
      label: _str(json['label']),
      deepLink: _str(json['deepLink']),
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const {},
      requiresConfirmation: json['requiresConfirmation'] == true,
    );
  }

  final String label;
  final String deepLink;
  final Map<String, dynamic> payload;
  final bool requiresConfirmation;
}

class AdaptiveFactorBreakdownDto {
  const AdaptiveFactorBreakdownDto({
    required this.urgency,
    required this.impact,
    required this.ageBoost,
    required this.learnedWeight,
  });

  factory AdaptiveFactorBreakdownDto.fromJson(Map<String, dynamic> json) {
    return AdaptiveFactorBreakdownDto(
      urgency: _double(json['urgency']),
      impact: _double(json['impact']),
      ageBoost: _double(json['ageBoost']),
      learnedWeight: _double(json['learnedWeight']),
    );
  }

  final double urgency;
  final double impact;
  final double ageBoost;
  final double learnedWeight;
}

class AdaptivePriorityItemDto {
  const AdaptivePriorityItemDto({
    required this.itemKey,
    required this.type,
    required this.title,
    required this.detail,
    required this.score,
    required this.reason,
    required this.action,
    required this.factorBreakdown,
    this.lifecycleState,
    this.visibilityReason,
  });

  factory AdaptivePriorityItemDto.fromJson(Map<String, dynamic> json) {
    return AdaptivePriorityItemDto(
      itemKey: _str(json['itemKey']),
      type: _str(json['type']),
      title: _str(json['title']),
      detail: _str(json['detail']),
      score: _int(json['score']),
      reason: _str(json['reason']),
      action: json['action'] is Map<String, dynamic>
          ? AdaptiveActionDto.fromJson(json['action'] as Map<String, dynamic>)
          : null,
      factorBreakdown: json['factorBreakdown'] is Map<String, dynamic>
          ? AdaptiveFactorBreakdownDto.fromJson(json['factorBreakdown'] as Map<String, dynamic>)
          : null,
      // Living Dashboard overlay. Absent on a backend that predates it and on
      // the mock repository, so both stay null rather than defaulting to a
      // state the user never actually set.
      lifecycleState: json['lifecycleState'] is String
          ? json['lifecycleState'] as String
          : null,
      visibilityReason: json['visibilityReason'] is String
          ? json['visibilityReason'] as String
          : null,
    );
  }

  final String itemKey;
  final String type;
  final String title;
  final String detail;
  final int score;
  final String reason;
  final AdaptiveActionDto? action;
  final AdaptiveFactorBreakdownDto? factorBreakdown;
  final String? lifecycleState;
  final String? visibilityReason;
}

class AdaptiveFeedDto {
  const AdaptiveFeedDto({
    required this.persona,
    required this.items,
    required this.criticalCount,
    required this.degraded,
  });

  /// Parses the ENVELOPE `data` object of a priorities/recommendations response.
  factory AdaptiveFeedDto.fromEnvelopeData(Map<String, dynamic> data) {
    final counts = data['counts'] is Map<String, dynamic>
        ? data['counts'] as Map<String, dynamic>
        : const {};
    return AdaptiveFeedDto(
      persona: _str(data['persona']),
      items: _items(data, 'items').map(AdaptivePriorityItemDto.fromJson).toList(),
      criticalCount: _int(counts['critical']),
      degraded: data['degraded'] == true,
    );
  }

  final String persona;
  final List<AdaptivePriorityItemDto> items;
  final int criticalCount;
  final bool degraded;
}

class QuickActionResolverDto {
  const QuickActionResolverDto({required this.kind, required this.target, required this.prompt});

  factory QuickActionResolverDto.fromJson(Map<String, dynamic> json) {
    return QuickActionResolverDto(
      kind: _str(json['kind']),
      target: _str(json['target']),
      prompt: json['prompt'] is String ? json['prompt'] as String : null,
    );
  }

  final String kind;
  final String target;
  final String? prompt;
}

class AdaptiveQuickActionDto {
  const AdaptiveQuickActionDto({
    required this.id,
    required this.label,
    required this.tier,
    required this.requiresEntity,
    required this.resolver,
  });

  factory AdaptiveQuickActionDto.fromJson(Map<String, dynamic> json) {
    return AdaptiveQuickActionDto(
      id: _str(json['id']),
      label: _str(json['label']),
      tier: _str(json['tier'], 't1'),
      requiresEntity: json['requiresEntity'] is String ? json['requiresEntity'] as String : null,
      resolver: json['resolver'] is Map<String, dynamic>
          ? QuickActionResolverDto.fromJson(json['resolver'] as Map<String, dynamic>)
          : const QuickActionResolverDto(kind: 'endpoint', target: '', prompt: null),
    );
  }

  final String id;
  final String label;
  final String tier;
  final String? requiresEntity;
  final QuickActionResolverDto resolver;
}

List<AdaptiveQuickActionDto> parseQuickActions(Map<String, dynamic> data) {
  return _items(data, 'items').map(AdaptiveQuickActionDto.fromJson).toList();
}

class SearchResultItemDto {
  const SearchResultItemDto({
    required this.category,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.deepLink,
  });

  factory SearchResultItemDto.fromJson(Map<String, dynamic> json) {
    return SearchResultItemDto(
      category: _str(json['category']),
      id: _str(json['id']),
      title: _str(json['title']),
      subtitle: _str(json['subtitle']),
      deepLink: _str(json['deepLink']),
    );
  }

  final String category;
  final String id;
  final String title;
  final String subtitle;
  final String deepLink;
}

class SearchGroupDto {
  const SearchGroupDto({
    required this.category,
    required this.label,
    required this.results,
    required this.total,
    this.offset = 0,
  });

  factory SearchGroupDto.fromJson(Map<String, dynamic> json) {
    return SearchGroupDto(
      category: _str(json['category']),
      label: _str(json['label']),
      results: _items(json, 'results').map(SearchResultItemDto.fromJson).toList(),
      total: _int(json['total']),
      offset: _int(json['offset']),
    );
  }

  final String category;
  final String label;
  final List<SearchResultItemDto> results;
  final int total;
  final int offset;
}

class UniversalSearchResultDto {
  const UniversalSearchResultDto({required this.query, required this.groups});

  factory UniversalSearchResultDto.fromEnvelopeData(Map<String, dynamic> data) {
    return UniversalSearchResultDto(
      query: _str(data['query']),
      groups: _items(data, 'groups').map(SearchGroupDto.fromJson).toList(),
    );
  }

  final String query;
  final List<SearchGroupDto> groups;
}
