import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/theme_extensions.dart';
import '../admissions_models.dart';

/// Hot / Warm / Cold lead score chip (CRM spec).
class AdmissionsLeadScoreChip extends StatelessWidget {
  const AdmissionsLeadScoreChip({
    super.key,
    required this.score,
  });

  final LeadScore score;

  @override
  Widget build(BuildContext context) {
    final tone = switch (score) {
      LeadScore.hot => KpiAccent.error,
      LeadScore.warm => KpiAccent.warning,
      LeadScore.cold => KpiAccent.primary,
    };

    return AksharaStatusChip(
      label: score.label,
      tone: tone,
      semanticLabel: '${score.label} lead score',
    );
  }
}
