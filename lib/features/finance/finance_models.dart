import 'package:flutter/material.dart';

import '../admissions/admissions_models.dart';

/// Finance sub-module destinations (FN-01 → FN-05 Phase 1).
enum FinanceScreen {
  dashboard,
  feeStructures,
  studentAccounts,
  feeAssignment,
  collections;

  String get label => switch (this) {
        FinanceScreen.dashboard => 'Dashboard',
        FinanceScreen.feeStructures => 'Fee Structures',
        FinanceScreen.studentAccounts => 'Student Accounts',
        FinanceScreen.feeAssignment => 'Fee Assignment',
        FinanceScreen.collections => 'Collections',
      };
}

enum FeeStructureCategory { tuition, transport, hostel, activity }

enum FeeStructureStatus { active, inactive }

enum FeeAccountStatus { active, overdue, closed, pending }

enum CollectionStatus { completed, pending, failed, refunded }

enum InstallmentPlanType { quarterly, termly, monthly, annual }

@immutable
class FinanceKpi {
  const FinanceKpi({
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
class CollectionTrendPoint {
  const CollectionTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class RecentPayment {
  const RecentPayment({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.amount,
    required this.mode,
    required this.receiptNumber,
    required this.collectedAt,
    required this.status,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String amount;
  final String mode;
  final String receiptNumber;
  final String collectedAt;
  final CollectionStatus status;
}

@immutable
class FinanceDashboardData {
  const FinanceDashboardData({
    required this.kpis,
    required this.collectionTrend,
    required this.recentPayments,
    required this.aiInsight,
    required this.outstandingAmount,
    required this.defaultersCount,
  });

  final List<FinanceKpi> kpis;
  final List<CollectionTrendPoint> collectionTrend;
  final List<RecentPayment> recentPayments;
  final String aiInsight;
  final String outstandingAmount;
  final int defaultersCount;
}

@immutable
class FeeCategoryLine {
  const FeeCategoryLine({
    required this.category,
    required this.label,
    required this.amount,
  });

  final FeeStructureCategory category;
  final String label;
  final String amount;
}

@immutable
class FinanceFeeStructure {
  const FinanceFeeStructure({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.totalAnnual,
    required this.categories,
    required this.status,
    required this.installmentOptions,
    required this.classRange,
  });

  final String id;
  final String name;
  final String academicYear;
  final String totalAnnual;
  final List<FeeCategoryLine> categories;
  final FeeStructureStatus status;
  final List<int> installmentOptions;
  final String classRange;
}

@immutable
class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.label,
    required this.installmentCount,
    required this.type,
  });

  final String id;
  final String label;
  final int installmentCount;
  final InstallmentPlanType type;
}

@immutable
class StudentFeeAccount {
  const StudentFeeAccount({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.feeStructureName,
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    required this.status,
    required this.lastPaymentDate,
    required this.installmentPlan,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String feeStructureName;
  final String totalDue;
  final String totalPaid;
  final String balance;
  final FeeAccountStatus status;
  final String lastPaymentDate;
  final String installmentPlan;
}

@immutable
class FeeAssignmentDraft {
  const FeeAssignmentDraft({
    required this.handoffId,
    required this.feeStructureId,
    required this.installmentPlanId,
    required this.includeTransport,
    required this.includeHostel,
  });

  final String handoffId;
  final String feeStructureId;
  final String installmentPlanId;
  final bool includeTransport;
  final bool includeHostel;
}

@immutable
class GeneratedFeeAccountPreview {
  const GeneratedFeeAccountPreview({
    required this.accountId,
    required this.studentName,
    required this.admissionNumber,
    required this.feeStructureName,
    required this.totalDue,
    required this.installmentSummary,
    required this.addOns,
  });

  final String accountId;
  final String studentName;
  final String admissionNumber;
  final String feeStructureName;
  final String totalDue;
  final String installmentSummary;
  final List<String> addOns;
}

@immutable
class CollectionPayment {
  const CollectionPayment({
    required this.id,
    required this.receiptNumber,
    required this.studentName,
    required this.admissionNumber,
    required this.amount,
    required this.mode,
    required this.collectedAt,
    required this.collectedBy,
    required this.status,
    required this.classLabel,
  });

  final String id;
  final String receiptNumber;
  final String studentName;
  final String admissionNumber;
  final String amount;
  final String mode;
  final String collectedAt;
  final String collectedBy;
  final CollectionStatus status;
  final String classLabel;
}

@immutable
class DailyCollectionSummary {
  const DailyCollectionSummary({
    required this.dateLabel,
    required this.totalCollected,
    required this.transactionCount,
    required this.cashAmount,
    required this.upiAmount,
    required this.pendingReconciliation,
  });

  final String dateLabel;
  final String totalCollected;
  final int transactionCount;
  final String cashAmount;
  final String upiAmount;
  final int pendingReconciliation;
}

@immutable
class FinanceHandoffQueueItem {
  const FinanceHandoffQueueItem({
    required this.handoff,
    required this.effectiveStatus,
  });

  final ApprovedStudentHandoff handoff;
  final FeeHandoffStatus effectiveStatus;
}
