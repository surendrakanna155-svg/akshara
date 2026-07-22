import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_report_card.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import 'widgets/report_card_view.dart';

/// Neutral fallback when the real per-tenant school name is momentarily
/// unavailable (e.g. the dashboard/exams snapshot hasn't resolved yet) — never
/// a hardcoded specific school's name.
const String _reportCardSchoolNameFallback = 'School';

/// In-app report card (Slice 6). Reused by parent and student apps — each passes
/// the provider that builds the card for its own student, and its own real
/// per-tenant [schoolName] (sourced from `schools.name` via that app's own
/// exams snapshot — parent and student scopes read different backend routes,
/// so this widget stays scope-agnostic and takes the resolved name as input).
class ReportCardScreen extends ConsumerWidget {
  const ReportCardScreen({super.key, required this.provider, required this.schoolName});

  final ProviderListenable<ExamReportCard?> provider;
  final String schoolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(provider);
    final resolvedSchoolName =
        schoolName.isNotEmpty ? schoolName : _reportCardSchoolNameFallback;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Report card'),
        actions: [
          if (card != null)
            IconButton(
              key: QaTestKeys.reportCardShareButton,
              tooltip: 'Export / share PDF',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => ref
                  .read(aksharaReportExportServiceProvider)
                  .shareReportCardPdf(
                    card: card,
                    schoolName: resolvedSchoolName,
                  ),
            ),
        ],
      ),
      // DS V2 P4 — premium persona canvas behind the report card.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: card == null
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
      ),
    );
  }
}
