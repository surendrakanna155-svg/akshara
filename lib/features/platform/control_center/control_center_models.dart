import 'package:flutter/material.dart';

/// Platform PII privacy banner text (AksharaControlCenter.md §2).
const String kControlCenterPiiBannerMessage =
    'Platform view · No school student or parent PII · Aggregates only';

/// Control Center sub-module destinations (ACC-01 → ACC-12).
enum ControlCenterScreen {
  dashboard,
  intelligence,
  schools,
  subscriptions,
  billing,
  crm,
  support,
  success,
  whiteLabel,
  analytics,
  monitoring,
  roles,
  settings,
  providers,
  features;

  String get label => switch (this) {
        ControlCenterScreen.dashboard => 'Dashboard',
        ControlCenterScreen.intelligence => 'Platform Analytics',
        ControlCenterScreen.schools => 'Schools',
        ControlCenterScreen.subscriptions => 'Subscriptions',
        ControlCenterScreen.billing => 'Billing',
        ControlCenterScreen.crm => 'CRM',
        ControlCenterScreen.support => 'Support',
        ControlCenterScreen.success => 'Success',
        ControlCenterScreen.whiteLabel => 'White Label',
        ControlCenterScreen.analytics => 'Analytics',
        ControlCenterScreen.monitoring => 'Monitoring',
        ControlCenterScreen.roles => 'Roles',
        ControlCenterScreen.settings => 'Settings',
        ControlCenterScreen.providers => 'Providers',
        ControlCenterScreen.features => 'Features',
      };
}

enum PlatformProviderCategory { ai, whatsapp, sms }

@immutable
class PlatformProviderConfig {
  const PlatformProviderConfig({
    required this.id,
    required this.providerCategory,
    required this.providerName,
    required this.hasCredential,
    required this.isActive,
    required this.isPrimary,
    required this.healthStatus,
  });

  final String id;
  final String providerCategory;
  final String providerName;
  final bool hasCredential;
  final bool isActive;
  final bool isPrimary;
  final String healthStatus;
}

@immutable
class PlatformUsageAnalytics {
  const PlatformUsageAnalytics({
    required this.totalEvents,
    required this.totalCostInr,
    required this.byCategory,
  });

  final int totalEvents;
  final double totalCostInr;
  final Map<String, PlatformUsageCategoryStats> byCategory;
}

@immutable
class PlatformUsageCategoryStats {
  const PlatformUsageCategoryStats({required this.events, required this.costInr});
  final int events;
  final double costInr;
}

@immutable
class FeatureEnablement {
  const FeatureEnablement({
    required this.schoolId,
    required this.featureKey,
    required this.enabled,
  });

  final String schoolId;
  final String featureKey;
  final bool enabled;
}

@immutable
class ControlCenterProvidersData {
  const ControlCenterProvidersData({
    required this.providers,
    required this.usage,
    required this.features,
  });

  final List<PlatformProviderConfig> providers;
  final PlatformUsageAnalytics usage;
  final List<FeatureEnablement> features;
}

/// PRC-A Batch 3 — AI credit wallet health verdict (mirrors `walletHealth()` in
/// `ai_wallet_repository.ts`): healthy / low (<=10% of the last top-up left) /
/// empty (availableUnits <= 0).
enum AiWalletHealth { healthy, low, empty }

@immutable
class AiWalletBalance {
  const AiWalletBalance({
    required this.grantedUnits,
    required this.debitedUnits,
    required this.reservedUnits,
    required this.availableUnits,
    required this.lastTopUpUnits,
    required this.health,
  });

  /// Everything ever granted (top-ups + adjustments + expiries, signed).
  final int grantedUnits;

  /// Committed debits from AI calls already served.
  final int debitedUnits;

  /// Units held by in-flight (pending) reservations.
  final int reservedUnits;

  /// granted - debited - reserved. MAY be negative — an admin correction or an
  /// expiry can legitimately push this below zero; the UI must not clamp it.
  final int availableUnits;

  /// Units of the most recent top_up — the denominator for the low-balance
  /// signal.
  final int lastTopUpUnits;

  final AiWalletHealth health;
}

@immutable
class AiCreditEntry {
  const AiCreditEntry({
    required this.id,
    required this.entryType,
    required this.units,
    required this.reason,
    this.actorId,
    this.externalRef,
    required this.createdAt,
  });

  final String id;

  /// 'top_up' | 'adjustment' | 'expiry'.
  final String entryType;

  /// Signed: positive for a top-up, negative for an expiry, either for an
  /// adjustment.
  final int units;
  final String reason;
  final String? actorId;
  final String? externalRef;
  final String createdAt;
}

@immutable
class AiWalletData {
  const AiWalletData({
    required this.balance,
    required this.entries,
  });

  final AiWalletBalance balance;
  final List<AiCreditEntry> entries;
}

enum PlatformSchoolStatus { active, trial, suspended, churnRisk }

enum SubscriptionPlan { standard, premium, enterprise }

enum SubscriptionStatus { active, trial, expiring, cancelled }

enum CrmPipelineStage {
  lead,
  contacted,
  demo,
  proposal,
  negotiation,
  won,
  lost,
}

enum SupportTicketStatus { open, inProgress, resolved, closed }

enum PlatformHealthStatus { healthy, degraded, critical }

enum ErpModuleId {
  admissions,
  finance,
  sis,
  hr,
  management,
  transport,
  hostel,
  library,
  inventory,
  alumni,
}

@immutable
class ControlCenterKpi {
  const ControlCenterKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class ControlCenterTrendPoint {
  const ControlCenterTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class ControlCenterSegment {
  const ControlCenterSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class ErpModuleReference {
  const ErpModuleReference({
    required this.module,
    required this.label,
    required this.route,
    required this.schoolCount,
    required this.adoptionPercent,
  });

  final ErpModuleId module;
  final String label;
  final String route;
  final int schoolCount;
  final int adoptionPercent;
}

@immutable
class PlatformSchool {
  const PlatformSchool({
    required this.id,
    required this.name,
    required this.plan,
    required this.studentCount,
    required this.status,
    required this.createdDate,
    required this.mrrLakhs,
    required this.healthScore,
    required this.region,
    required this.tenantId,
  });

  final String id;
  final String name;
  final SubscriptionPlan plan;
  final int studentCount;
  final PlatformSchoolStatus status;
  final String createdDate;
  final double mrrLakhs;
  final int healthScore;
  final String region;
  final String tenantId;
}

@immutable
class SubscriptionPlanInfo {
  const SubscriptionPlanInfo({
    required this.plan,
    required this.monthlyPriceLakhs,
    required this.schoolCount,
    required this.features,
    required this.dedicatedDb,
  });

  final SubscriptionPlan plan;
  final double monthlyPriceLakhs;
  final int schoolCount;
  final List<String> features;
  final bool dedicatedDb;
}

@immutable
class ControlCenterSubscriptionsData {
  const ControlCenterSubscriptionsData({
    required this.plans,
    required this.expiringCount,
    required this.renewalRatePercent,
    required this.planDistribution,
  });

  final List<SubscriptionPlanInfo> plans;
  final int expiringCount;
  final int renewalRatePercent;
  final List<ControlCenterSegment> planDistribution;
}

@immutable
class BillingInvoice {
  const BillingInvoice({
    required this.id,
    required this.schoolName,
    required this.amountLakhs,
    required this.dueDate,
    required this.status,
    required this.plan,
  });

  final String id;
  final String schoolName;
  final double amountLakhs;
  final String dueDate;
  final String status;
  final SubscriptionPlan plan;
}

@immutable
class ControlCenterBillingData {
  const ControlCenterBillingData({
    required this.mrrLakhs,
    required this.arrLakhs,
    required this.outstandingLakhs,
    required this.invoices,
    required this.revenueTrend,
    required this.revenueByPlan,
  });

  final double mrrLakhs;
  final double arrLakhs;
  final double outstandingLakhs;
  final List<BillingInvoice> invoices;
  final List<ControlCenterTrendPoint> revenueTrend;
  final List<ControlCenterSegment> revenueByPlan;
}

@immutable
class CrmDeal {
  const CrmDeal({
    required this.id,
    required this.schoolName,
    required this.contactName,
    required this.stage,
    required this.estimatedMrrLakhs,
    required this.owner,
    required this.lastActivity,
  });

  final String id;
  final String schoolName;
  final String contactName;
  final CrmPipelineStage stage;
  final double estimatedMrrLakhs;
  final String owner;
  final String lastActivity;
}

@immutable
class ControlCenterCrmData {
  const ControlCenterCrmData({
    required this.deals,
    required this.pipelineValueLakhs,
    required this.winRatePercent,
    required this.stageDistribution,
  });

  final List<CrmDeal> deals;
  final double pipelineValueLakhs;
  final int winRatePercent;
  final List<ControlCenterSegment> stageDistribution;
}

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.schoolName,
    required this.status,
    required this.priority,
    required this.slaRemaining,
    required this.assignee,
    required this.createdDate,
  });

  final String id;
  final String subject;
  final String schoolName;
  final SupportTicketStatus status;
  final String priority;
  final String slaRemaining;
  final String assignee;
  final String createdDate;
}

@immutable
class CustomerSuccessSchool {
  const CustomerSuccessSchool({
    required this.schoolId,
    required this.schoolName,
    required this.adoptionScore,
    required this.renewalProbability,
    required this.churnRisk,
    required this.csOwner,
    required this.lowUsageModules,
  });

  final String schoolId;
  final String schoolName;
  final int adoptionScore;
  final int renewalProbability;
  final bool churnRisk;
  final String csOwner;
  final List<String> lowUsageModules;
}

@immutable
class ControlCenterSuccessData {
  const ControlCenterSuccessData({
    required this.schools,
    required this.atRiskCount,
    required this.avgAdoptionScore,
    required this.aiInsight,
  });

  final List<CustomerSuccessSchool> schools;
  final int atRiskCount;
  final int avgAdoptionScore;
  final String aiInsight;
}

@immutable
class WhiteLabelConfig {
  const WhiteLabelConfig({
    required this.schoolId,
    required this.schoolName,
    required this.logoUrl,
    required this.primaryColorHex,
    required this.customDomain,
    required this.loginBackgroundUrl,
    required this.isPublished,
  });

  final String schoolId;
  final String schoolName;
  final String logoUrl;
  final String primaryColorHex;
  final String customDomain;
  final String loginBackgroundUrl;
  final bool isPublished;
}

@immutable
class ControlCenterAnalyticsData {
  const ControlCenterAnalyticsData({
    required this.schoolGrowthTrend,
    required this.studentGrowthTrend,
    required this.moduleUsage,
    required this.marketingAttribution,
  });

  final List<ControlCenterTrendPoint> schoolGrowthTrend;
  final List<ControlCenterTrendPoint> studentGrowthTrend;
  final List<ControlCenterSegment> moduleUsage;
  final List<ControlCenterSegment> marketingAttribution;
}

@immutable
class PlatformServiceHealth {
  const PlatformServiceHealth({
    required this.serviceName,
    required this.status,
    required this.uptimePercent,
    required this.lastIncident,
  });

  final String serviceName;
  final PlatformHealthStatus status;
  final String uptimePercent;
  final String lastIncident;
}

@immutable
class ControlCenterMonitoringData {
  const ControlCenterMonitoringData({
    required this.services,
    required this.errorRatePercent,
    required this.activeDeployments,
    required this.featureFlags,
  });

  final List<PlatformServiceHealth> services;
  final double errorRatePercent;
  final int activeDeployments;
  final List<String> featureFlags;
}

@immutable
class PlatformRole {
  const PlatformRole({
    required this.id,
    required this.name,
    required this.description,
    required this.permissionCount,
    required this.userCount,
  });

  final String id;
  final String name;
  final String description;
  final int permissionCount;
  final int userCount;
}

@immutable
class ControlCenterRolesData {
  const ControlCenterRolesData({
    required this.roles,
    required this.permissionGroups,
  });

  final List<PlatformRole> roles;
  final List<String> permissionGroups;
}

@immutable
class ControlCenterSettingItem {
  const ControlCenterSettingItem({
    required this.id,
    required this.label,
    required this.value,
    required this.description,
    required this.editable,
  });

  final String id;
  final String label;
  final String value;
  final String description;
  final bool editable;
}

@immutable
class ControlCenterSettingsSection {
  const ControlCenterSettingsSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<ControlCenterSettingItem> items;
}

@immutable
class ControlCenterSettingsData {
  const ControlCenterSettingsData({
    required this.sections,
    required this.maintenanceMode,
  });

  final List<ControlCenterSettingsSection> sections;
  final bool maintenanceMode;
}

@immutable
class ControlCenterDashboardData {
  const ControlCenterDashboardData({
    required this.kpis,
    required this.schoolGrowthTrend,
    required this.revenueTrend,
    required this.planDistribution,
    required this.expiringSchools,
    required this.erpModules,
    required this.aiInsight,
  });

  final List<ControlCenterKpi> kpis;
  final List<ControlCenterTrendPoint> schoolGrowthTrend;
  final List<ControlCenterTrendPoint> revenueTrend;
  final List<ControlCenterSegment> planDistribution;
  final List<String> expiringSchools;
  final List<ErpModuleReference> erpModules;
  final String aiInsight;
}
