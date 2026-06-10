import 'package:flutter/foundation.dart';

@immutable
class OnboardingImportJob {
  const OnboardingImportJob({
    required this.id,
    required this.importType,
    required this.status,
    required this.fileName,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.committedRows,
  });

  final String id;
  final String importType;
  final String status;
  final String fileName;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateRows;
  final int committedRows;
}

@immutable
class OnboardingImportPreviewRow {
  const OnboardingImportPreviewRow({
    required this.rowNumber,
    required this.status,
    required this.errors,
  });

  final int rowNumber;
  final String status;
  final List<String> errors;
}

@immutable
class OnboardingImportPreviewResult {
  const OnboardingImportPreviewResult({
    required this.job,
    required this.preview,
  });

  final OnboardingImportJob job;
  final List<OnboardingImportPreviewRow> preview;
}

@immutable
class OnboardingInvite {
  const OnboardingInvite({
    required this.id,
    required this.inviteType,
    required this.recipientPhone,
    required this.recipientLabel,
    required this.status,
    required this.channel,
    required this.deepLink,
    this.whatsappLink,
  });

  final String id;
  final String inviteType;
  final String recipientPhone;
  final String recipientLabel;
  final String status;
  final String channel;
  final String deepLink;
  final String? whatsappLink;
}

@immutable
class OnboardingDashboardData {
  const OnboardingDashboardData({
    required this.recentJobs,
    required this.pendingInvites,
    required this.totalInvites,
  });

  final List<OnboardingImportJob> recentJobs;
  final int pendingInvites;
  final int totalInvites;
}
