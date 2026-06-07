import 'package:flutter/material.dart';

import '../../../../../features/management/management_models.dart';

/// Parses Management API enum strings and presentation helpers.
abstract final class ManagementEnumCodec {
  static ManagementApprovalType parseApprovalType(String? value) {
    return ManagementApprovalType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ManagementApprovalType.budget,
    );
  }

  static String approvalTypeToApi(ManagementApprovalType type) => type.name;

  static ManagementApprovalStatus parseApprovalStatus(String? value) {
    return ManagementApprovalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ManagementApprovalStatus.pending,
    );
  }

  static String approvalStatusToApi(ManagementApprovalStatus status) =>
      status.name;

  static ManagementAiRecommendation parseAiRecommendation(String? value) {
    return ManagementAiRecommendation.values.firstWhere(
      (recommendation) => recommendation.name == value,
      orElse: () => ManagementAiRecommendation.review,
    );
  }

  static String aiRecommendationToApi(ManagementAiRecommendation recommendation) =>
      recommendation.name;

  static IconData iconForKpi(String? iconName, String? accentName) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'trending_up' => Icons.trending_up,
        'account_balance_wallet_outlined' =>
          Icons.account_balance_wallet_outlined,
        'groups_outlined' => Icons.groups_outlined,
        'school_outlined' => Icons.school_outlined,
        'fact_check_outlined' => Icons.fact_check_outlined,
        'pending_actions_outlined' => Icons.pending_actions_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (accentName) {
      'primary' => Icons.trending_up,
      'success' => Icons.account_balance_wallet_outlined,
      'warning' => Icons.pending_actions_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
