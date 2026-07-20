import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_report_card.dart';
import '../parent_active_child_provider.dart';
import 'parent_exams_provider.dart';

/// Report card for the active child, built from the SERVER-BACKED published
/// results feed — PRA-P0-06 / PRA-P1-32 (S4).
///
/// Previously this read a local in-memory `ExamAdministrationStore`; on real
/// (API) data that store is never populated by the server, so the card was
/// disconnected from the child's actual published results. It now mirrors
/// `parent_exams_provider` (already the active-child-scoped, server-backed exams
/// feed) and builds the card from that same `getExams` data. Null until at least
/// one result is published for the child.
final parentReportCardProvider = Provider<ExamReportCard?>((ref) {
  final data = ref.watch(parentExamsProvider);
  return ExamReportCardBuilder.fromPublishedResults(
    // The exams feed is already scoped to the active child; carry its id so the
    // exported PDF shows the real Student ID instead of a fabricated one.
    sisStudentId: ref.watch(parentActiveStudentIdProvider),
    studentName: data.childName,
    classLabel: data.childClass,
    results: [
      // PRA-P0-06 / PRA-P1-32 (S4) — server source of truth for PUBLISHED results.
      for (final result in data.examResults)
        PublishedResultLine(
          subject: result.title,
          examTitle: result.title,
          termLabel: result.termLabel,
          score: result.scoreObtained,
          maxScore: result.maxScore,
          grade: result.grade,
        ),
    ],
  );
});
