import 'package:flutter/material.dart';

import '../../../../core/exams/exam_report_card.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';

/// Renders a per-student, per-term exam report card. Rank is shown only when the
/// school enables it ([ExamReportCard.rankShown]).
class ReportCardView extends StatelessWidget {
  const ReportCardView({super.key, required this.card});

  final ExamReportCard card;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.primaryContainer,
          borderRadius: AksharaRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.studentName, style: text.titleMedium),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  '${card.classLabel} · ${card.termLabel}',
                  style: text.bodySmall
                      .copyWith(color: colors.onPrimaryContainer),
                ),
                if (card.attendancePercent != null)
                  Text(
                    'Attendance: ${card.attendancePercent}%',
                    style: text.bodySmall
                        .copyWith(color: colors.onPrimaryContainer),
                  ),
                if (card.rankShown) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  AksharaStatusChip(
                    key: QaTestKeys.reportCardRankChip,
                    label: 'Rank ${card.rank} of ${card.classSize}',
                    tone: KpiAccent.indigo,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        AksharaSectionHeader(title: 'Subjects', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AksharaRadius.card,
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < card.subjects.length; i++) ...[
                _SubjectRow(line: card.subjects[i]),
                if (i < card.subjects.length - 1)
                  Divider(height: 1, color: colors.outlineVariant),
              ],
              Divider(height: 1, color: colors.outlineVariant),
              _TotalRow(card: card),
            ],
          ),
        ),
        if ((card.remark ?? '').isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s4),
          AksharaSectionHeader(title: 'Class teacher remark', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          Material(
            key: QaTestKeys.reportCardRemark,
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AksharaRadius.card,
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.remark!, style: text.bodyMedium),
                  if ((card.remarkAuthorName ?? '').isNotEmpty) ...[
                    const SizedBox(height: AksharaSpacing.s2),
                    Text(
                      '— ${card.remarkAuthorName}',
                      style: text.bodySmall
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.line});

  final ReportCardSubjectLine line;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s3,
      ),
      child: Row(
        children: [
          Expanded(child: Text(line.subject, style: text.bodyMedium)),
          Text('${line.score}/${line.maxScore}', style: text.bodyMedium),
          const SizedBox(width: AksharaSpacing.s3),
          SizedBox(
            width: 44,
            child: Text(
              '${line.percent}%',
              style: text.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          SizedBox(
            width: 36,
            child: Text(
              line.grade,
              style: text.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.card});

  final ExamReportCard card;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total',
              style: text.titleSmall.copyWith(color: colors.primary),
            ),
          ),
          Text(
            '${card.totalScore}/${card.totalMax}',
            style: text.titleSmall,
          ),
          const SizedBox(width: AksharaSpacing.s3),
          SizedBox(
            width: 44,
            child: Text(
              '${card.overallPercent}%',
              style: text.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          SizedBox(
            width: 36,
            child: Text(
              card.overallGrade,
              style: text.titleSmall.copyWith(color: colors.primary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
