import 'package:flutter/material.dart';

import '../../../../../features/control_center/control_center_models.dart';

/// Parses Control Center API enum strings and presentation helpers.
abstract final class ControlCenterEnumCodec {
  static PlatformSchoolStatus parseSchoolStatus(String? value) {
    return PlatformSchoolStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PlatformSchoolStatus.active,
    );
  }

  static String schoolStatusToApi(PlatformSchoolStatus status) => status.name;

  static SubscriptionPlan parseSubscriptionPlan(String? value) {
    return SubscriptionPlan.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => SubscriptionPlan.standard,
    );
  }

  static String subscriptionPlanToApi(SubscriptionPlan plan) => plan.name;

  static SubscriptionStatus parseSubscriptionStatus(String? value) {
    return SubscriptionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SubscriptionStatus.active,
    );
  }

  static String subscriptionStatusToApi(SubscriptionStatus status) =>
      status.name;

  static CrmPipelineStage parseCrmStage(String? value) {
    return CrmPipelineStage.values.firstWhere(
      (stage) => stage.name == value,
      orElse: () => CrmPipelineStage.lead,
    );
  }

  static String crmStageToApi(CrmPipelineStage stage) => stage.name;

  static SupportTicketStatus parseTicketStatus(String? value) {
    return SupportTicketStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SupportTicketStatus.open,
    );
  }

  static String ticketStatusToApi(SupportTicketStatus status) => status.name;

  static PlatformHealthStatus parseHealthStatus(String? value) {
    return PlatformHealthStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PlatformHealthStatus.healthy,
    );
  }

  static String healthStatusToApi(PlatformHealthStatus status) => status.name;

  static ErpModuleId parseErpModuleId(String? value) {
    return ErpModuleId.values.firstWhere(
      (module) => module.name == value,
      orElse: () => ErpModuleId.admissions,
    );
  }

  static String erpModuleIdToApi(ErpModuleId module) => module.name;

  static IconData iconForKpi(String? iconName, String? accentName) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'apartment_outlined' => Icons.apartment_outlined,
        'check_circle_outline' => Icons.check_circle_outline,
        'hourglass_empty_outlined' => Icons.hourglass_empty_outlined,
        'event_busy_outlined' => Icons.event_busy_outlined,
        'payments_outlined' => Icons.payments_outlined,
        'trending_up_outlined' => Icons.trending_up_outlined,
        'warning_amber_outlined' => Icons.warning_amber_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (accentName) {
      'primary' => Icons.apartment_outlined,
      'success' => Icons.check_circle_outline,
      'warning' => Icons.hourglass_empty_outlined,
      'error' => Icons.warning_amber_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
