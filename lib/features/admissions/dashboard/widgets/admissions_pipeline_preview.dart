import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_section_empty.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_lead_score_chip.dart';

/// Horizontal kanban pipeline preview for AD-01.
class AdmissionsPipelinePreview extends StatelessWidget {
  const AdmissionsPipelinePreview({
    super.key,
    required this.pipeline,
    this.onViewBoard,
  });

  final List<PipelineStageSummary> pipeline;
  final VoidCallback? onViewBoard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    // An empty kanban inside a fixed 220px box reserves a screenful of blank
    // space under the header on day one. Collapse to an honest line instead.
    if (pipeline.isEmpty) {
      return const AksharaSectionEmpty(
        message: 'No enquiries yet. New leads appear here and move across the '
            'stages.',
        icon: Icons.view_kanban_outlined,
      );
    }

    return Semantics(
      container: true,
      label: 'Pipeline preview with ${pipeline.length} stages',
      child: SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pipeline.length,
          separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s3),
          itemBuilder: (context, index) {
            final column = pipeline[index];
            return SizedBox(
              width: 280,
              child: Material(
                color: colors.surfaceContainerLow,
                borderRadius: AksharaRadius.card,
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              column.stage.label,
                              style: text.labelLarge.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AksharaSpacing.s2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: AksharaRadius.chip,
                            ),
                            child: Text(
                              '${column.count}',
                              style: text.labelSmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AksharaSpacing.s3),
                      Expanded(
                        child: ListView.separated(
                          itemCount: column.leads.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AksharaSpacing.s2),
                          itemBuilder: (context, leadIndex) {
                            final lead = column.leads[leadIndex];
                            return _PipelineLeadCard(lead: lead);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PipelineLeadCard extends StatelessWidget {
  const _PipelineLeadCard({required this.lead});

  final PipelineLeadPreview lead;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label:
          '${lead.studentName}, class ${lead.classLabel}, ${lead.daysInStage} days in stage',
      child: Material(
        color: colors.surface,
        elevation: 1,
        shadowColor: colors.onSurface.withValues(alpha: 0.06),
        borderRadius: AksharaRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.studentName,
                      style: text.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AdmissionsLeadScoreChip(score: lead.score),
                ],
              ),
              Text(
                'Class ${lead.classLabel}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Row(
                children: [
                  Icon(
                    lead.source.icon,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AksharaSpacing.s1),
                  Text(
                    '${lead.daysInStage}d in stage',
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
