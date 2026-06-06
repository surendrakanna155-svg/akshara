import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/theme_extensions.dart';
import '../admissions_models.dart';

/// Application status chip for AD-03 workflow.
class AdmissionsApplicationStatusChip extends StatelessWidget {
  const AdmissionsApplicationStatusChip({
    super.key,
    required this.status,
  });

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      ApplicationStatus.draft => KpiAccent.neutral,
      ApplicationStatus.submitted => KpiAccent.primary,
      ApplicationStatus.documentsPending => KpiAccent.warning,
      ApplicationStatus.underReview => KpiAccent.warning,
      ApplicationStatus.approved => KpiAccent.success,
      ApplicationStatus.rejected => KpiAccent.error,
    };

    return AksharaStatusChip(
      label: status.label,
      tone: tone,
      semanticLabel: 'Application status ${status.label}',
    );
  }
}
