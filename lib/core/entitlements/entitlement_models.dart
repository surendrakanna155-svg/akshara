import 'package:flutter/foundation.dart';

/// B2 — Capability Gating → Entitlement Layer · Step 3 · client models.
///
/// Mirrors the backend contract (`GET /plans`, `GET /subscription`). These are
/// read-only on the client: the app never assigns or pays for a plan (entitlement
/// layer only — no billing/renewals/invoicing/payments/MRR/addons).

/// Canonical entitlement slugs (mirror `plan_entitlements` + the backend resolver).
abstract final class EntitlementSlugs {
  // Core modules — granted to every plan.
  static const admissions = 'module.admissions';
  static const finance = 'module.finance';
  static const sis = 'module.sis';
  static const management = 'module.management';
  static const attendance = 'module.attendance';
  static const exams = 'module.exams';
  // Optional modules — map onto the 8 SchoolCapabilities flags.
  static const transport = 'module.transport';
  static const hostel = 'module.hostel';
  static const library = 'module.library';
  static const inventory = 'module.inventory';
  static const alumni = 'module.alumni';
  static const hrPayroll = 'module.hr_payroll';
  static const multiBranch = 'module.multi_branch';
  static const trustOrg = 'module.trust_org';
  // Features.
  static const parentInsights = 'feature.parent_insights';
  static const aiPredictions = 'feature.ai_predictions';
}

/// Subscription lifecycle status (mirrors the DB CHECK constraint).
enum SubscriptionStatus {
  trial('trial'),
  active('active'),
  grace('grace'),
  suspended('suspended');

  const SubscriptionStatus(this.storageKey);
  final String storageKey;

  static SubscriptionStatus fromKey(String? key) {
    for (final value in SubscriptionStatus.values) {
      if (value.storageKey == key) return value;
    }
    return SubscriptionStatus.trial;
  }
}

@immutable
class PlanLimits {
  const PlanLimits({
    this.students,
    this.schools,
    this.graceBufferPercent = 0,
  });

  /// null = unlimited.
  final int? students;
  final int? schools;
  final double graceBufferPercent;

  Map<String, dynamic> toJson() => {
        'students': students,
        'schools': schools,
        'graceBufferPercent': graceBufferPercent,
      };

  factory PlanLimits.fromJson(Map<String, dynamic> json) => PlanLimits(
        students: (json['students'] as num?)?.toInt(),
        schools: (json['schools'] as num?)?.toInt(),
        graceBufferPercent:
            (json['graceBufferPercent'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class PlanUsage {
  const PlanUsage({this.students = 0, this.schools = 0});

  final int students;
  final int schools;

  Map<String, dynamic> toJson() => {'students': students, 'schools': schools};

  factory PlanUsage.fromJson(Map<String, dynamic> json) => PlanUsage(
        students: (json['students'] as num?)?.toInt() ?? 0,
        schools: (json['schools'] as num?)?.toInt() ?? 0,
      );
}

/// A plan from the catalog (`GET /plans`). Prices are display-only; B2 never
/// collects payment.
@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.slug,
    required this.name,
    required this.tierRank,
    required this.entitlements,
    this.description = '',
    this.limits = const PlanLimits(),
    this.basePricePaise = 0,
    this.isTrial = false,
  });

  final String slug;
  final String name;
  final String description;
  final int tierRank;
  final List<String> entitlements;
  final PlanLimits limits;
  final int basePricePaise;
  final bool isTrial;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tierRank: (json['tierRank'] as num?)?.toInt() ??
          (json['tier_rank'] as num?)?.toInt() ??
          0,
      entitlements: ((json['entitlements'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      limits: PlanLimits(
        students: (json['studentSlabMax'] as num?)?.toInt() ??
            (json['student_slab_max'] as num?)?.toInt(),
        schools: (json['maxSchools'] as num?)?.toInt() ??
            (json['max_schools'] as num?)?.toInt(),
        graceBufferPercent: (json['graceBufferPercent'] as num?)?.toDouble() ??
            (json['grace_buffer_percent'] as num?)?.toDouble() ??
            0,
      ),
      basePricePaise: (json['basePricePaise'] as num?)?.toInt() ??
          (json['base_price_paise'] as num?)?.toInt() ??
          0,
      isTrial: json['isTrial'] as bool? ?? json['is_trial'] as bool? ?? false,
    );
  }
}

/// One organization row for the superAdmin plan-assignment screen
/// (`GET /platform/subscriptions`). Read-only listing — no billing data.
@immutable
class OrganizationPlanAssignment {
  const OrganizationPlanAssignment({
    required this.organizationId,
    required this.organizationName,
    required this.organizationSlug,
    required this.planSlug,
    required this.status,
  });

  final String organizationId;
  final String organizationName;
  final String organizationSlug;
  final String planSlug;
  final String status;

  OrganizationPlanAssignment copyWith({String? planSlug, String? status}) {
    return OrganizationPlanAssignment(
      organizationId: organizationId,
      organizationName: organizationName,
      organizationSlug: organizationSlug,
      planSlug: planSlug ?? this.planSlug,
      status: status ?? this.status,
    );
  }

  factory OrganizationPlanAssignment.fromJson(Map<String, dynamic> json) {
    return OrganizationPlanAssignment(
      organizationId: json['organizationId'] as String? ??
          json['organization_id'] as String? ??
          '',
      organizationName: json['organizationName'] as String? ??
          json['organization_name'] as String? ??
          '',
      organizationSlug: json['organizationSlug'] as String? ??
          json['organization_slug'] as String? ??
          '',
      planSlug: json['planSlug'] as String? ??
          json['plan_slug'] as String? ??
          'trial',
      status: json['status'] as String? ?? 'trial',
    );
  }
}

/// The resolved subscription for the current org (`GET /subscription`):
/// plan summary, status, plan-allowed entitlement slugs, limits and usage.
@immutable
class ResolvedSubscription {
  const ResolvedSubscription({
    required this.planSlug,
    required this.planName,
    required this.tierRank,
    required this.status,
    required this.entitlements,
    this.fallbackApplied = false,
    this.trialEndsAt,
    this.graceEndsAt,
    this.limits = const PlanLimits(),
    this.usage = const PlanUsage(),
  });

  final String planSlug;
  final String planName;
  final int tierRank;
  final SubscriptionStatus status;

  /// Plan-allowed entitlement slugs (plan ∪ overrides.grant − overrides.revoke).
  final List<String> entitlements;

  /// True when no subscription row existed and the org was resolved as Trial.
  final bool fallbackApplied;
  final DateTime? trialEndsAt;
  final DateTime? graceEndsAt;
  final PlanLimits limits;
  final PlanUsage usage;

  bool allows(String slug) => entitlements.contains(slug);

  Set<String> get entitlementSet => entitlements.toSet();

  /// Trial fail-safe: used when the backend has no subscription / is unreachable
  /// and no cached value exists. Grants no optional modules.
  factory ResolvedSubscription.trialFallback() => const ResolvedSubscription(
        planSlug: 'trial',
        planName: 'Trial',
        tierRank: 0,
        status: SubscriptionStatus.trial,
        entitlements: <String>[],
        fallbackApplied: true,
        limits: PlanLimits(students: 100, schools: 1, graceBufferPercent: 10),
      );

  Map<String, dynamic> toJson() => {
        'planSlug': planSlug,
        'planName': planName,
        'tierRank': tierRank,
        'status': status.storageKey,
        'entitlements': entitlements,
        'fallbackApplied': fallbackApplied,
        'trialEndsAt': trialEndsAt?.toIso8601String(),
        'graceEndsAt': graceEndsAt?.toIso8601String(),
        'limits': limits.toJson(),
        'usage': usage.toJson(),
      };

  factory ResolvedSubscription.fromJson(Map<String, dynamic> json) {
    final plan = (json['plan'] as Map?)?.cast<String, dynamic>();
    return ResolvedSubscription(
      planSlug: plan?['slug'] as String? ?? json['planSlug'] as String? ?? 'trial',
      planName: plan?['name'] as String? ?? json['planName'] as String? ?? 'Trial',
      tierRank: (plan?['tierRank'] as num?)?.toInt() ??
          (json['tierRank'] as num?)?.toInt() ??
          0,
      status: SubscriptionStatus.fromKey(json['status'] as String?),
      entitlements: ((json['entitlements'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      fallbackApplied: json['fallbackApplied'] as bool? ?? false,
      trialEndsAt: json['trialEndsAt'] != null
          ? DateTime.tryParse(json['trialEndsAt'] as String)
          : null,
      graceEndsAt: json['graceEndsAt'] != null
          ? DateTime.tryParse(json['graceEndsAt'] as String)
          : null,
      limits: (json['limits'] is Map)
          ? PlanLimits.fromJson((json['limits'] as Map).cast<String, dynamic>())
          : const PlanLimits(),
      usage: (json['usage'] is Map)
          ? PlanUsage.fromJson((json['usage'] as Map).cast<String, dynamic>())
          : const PlanUsage(),
    );
  }
}
