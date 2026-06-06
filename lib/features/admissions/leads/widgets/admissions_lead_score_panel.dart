import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_kpi_card.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_lead_score_chip.dart';

/// Lead score and counselor assignment panel for AD-04.
class AdmissionsLeadScorePanel extends StatelessWidget {
  const AdmissionsLeadScorePanel({
    super.key,
    required this.profile,
    this.onCounselorChanged,
  });

  final LeadDetailProfile profile;
  final ValueChanged<String>? onCounselorChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final lead = profile.lead;
    final scoreAccent = switch (lead.score) {
      LeadScore.hot => KpiAccent.error,
      LeadScore.warm => KpiAccent.warning,
      LeadScore.cold => KpiAccent.primary,
    };

    return Semantics(
      container: true,
      label: 'Lead score ${lead.score.label}, counselor ${lead.counselor}',
      child: Material(
        color: colors.surface,
        borderRadius: AksharaRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lead score',
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              AksharaKpiCard(
                value: lead.score.label,
                subtitle: 'Engagement score',
                accent: scoreAccent,
                style: AksharaKpiCardStyle.filled,
                icon: Icons.local_fire_department_outlined,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              AdmissionsLeadScoreChip(score: lead.score),
              const SizedBox(height: AksharaSpacing.s4),
              Text(
                'Counselor assignment',
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              DropdownMenu<String>(
                initialSelection: lead.counselor,
                label: const Text('Assigned counselor'),
                dropdownMenuEntries: [
                  for (final name in profile.availableCounselors)
                    DropdownMenuEntry(value: name, label: name),
                ],
                onSelected: onCounselorChanged == null
                    ? null
                    : (value) {
                        if (value != null) onCounselorChanged!(value);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
