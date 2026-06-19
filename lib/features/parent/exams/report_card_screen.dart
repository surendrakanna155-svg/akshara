import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_report_card.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'widgets/report_card_view.dart';

/// In-app report card (Slice 6). Reused by parent and student apps — each passes
/// the provider that builds the card for its own student.
class ReportCardScreen extends ConsumerWidget {
  const ReportCardScreen({super.key, required this.provider});

  final ProviderListenable<ExamReportCard?> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(provider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AppBar(title: const Text('Report card')),
      body: card == null
          ? const AksharaEmptyState(
              icon: Icons.assignment_outlined,
              message: 'No published results yet for a report card.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AksharaSpacing.s4,
                AksharaSpacing.s4,
                AksharaSpacing.s4,
                AksharaSpacing.s6,
              ),
              child: ReportCardView(card: card),
            ),
    );
  }
}
