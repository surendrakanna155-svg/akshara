import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/theme_extensions.dart';
import '../admissions_models.dart';

/// Pipeline stage badge with semantic colors per Admissions spec.
class AdmissionsStageBadge extends StatelessWidget {
  const AdmissionsStageBadge({
    super.key,
    required this.stage,
  });

  final LeadStage stage;

  @override
  Widget build(BuildContext context) {
    final tone = switch (stage) {
      LeadStage.newEnquiry => KpiAccent.primary,
      LeadStage.contacted => KpiAccent.neutral,
      LeadStage.schoolVisit => KpiAccent.warning,
      LeadStage.demoClass => KpiAccent.warning,
      LeadStage.followUp => KpiAccent.neutral,
      LeadStage.admissionConfirmed => KpiAccent.success,
      LeadStage.joined => KpiAccent.success,
      LeadStage.lost => KpiAccent.error,
    };

    return AksharaStatusChip(
      label: stage.label,
      tone: tone,
      size: AksharaStatusChipSize.standard,
      semanticLabel: 'Pipeline stage ${stage.label}',
    );
  }
}
