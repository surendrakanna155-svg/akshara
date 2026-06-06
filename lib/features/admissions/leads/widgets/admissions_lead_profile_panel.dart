import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_lead_score_chip.dart';
import '../../widgets/admissions_stage_badge.dart';

/// Full lead profile summary for AD-04.
class AdmissionsLeadProfilePanel extends StatelessWidget {
  const AdmissionsLeadProfilePanel({
    super.key,
    required this.profile,
  });

  final LeadDetailProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final lead = profile.lead;

    return Semantics(
      container: true,
      label: 'Lead profile for ${lead.studentName}',
      child: Material(
        color: colors.surface,
        borderRadius: AksharaRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      lead.studentName.isNotEmpty
                          ? lead.studentName[0].toUpperCase()
                          : '?',
                      style: text.titleLarge.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.studentName,
                          style: text.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Class ${lead.classLabel} · ${lead.id}',
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdmissionsLeadScoreChip(score: lead.score),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              AdmissionsStageBadge(stage: lead.stage),
              const SizedBox(height: AksharaSpacing.s4),
              _InfoRow(label: 'Parent', value: lead.parentName),
              _InfoRow(label: 'Phone', value: lead.phone),
              _InfoRow(label: 'Email', value: profile.email),
              _InfoRow(label: 'Address', value: profile.address),
              _InfoRow(label: 'Source', value: lead.source.label),
              _InfoRow(label: 'Campaign', value: lead.campaign),
              _InfoRow(label: 'Created', value: profile.createdLabel),
              _InfoRow(label: 'Last activity', value: profile.lastActivityLabel),
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                'Notes',
                style: text.labelLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                profile.notes,
                style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: text.bodyMedium),
          ),
        ],
      ),
    );
  }
}
