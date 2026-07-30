import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_report_card.dart';
import 'student_exams_provider.dart';

/// Report card for the logged-in student, built from the SERVER-BACKED published
/// results feed — PRA-P0-06 / PRA-P1-32 (S4).
///
/// Previously this read a local in-memory `ExamAdministrationStore` scoped to a
/// hardcoded mock student id (`MockCanonicalStudentRegistry.primaryMobileStudentId`),
/// so on real (API) data it never reflected the server's published results and
/// targeted the wrong student. It now mirrors `parent_exams_provider` by reading
/// the same repository-backed exams feed (`getExams`) the report-card screen
/// already uses, so the exported card carries the authenticated student's own
/// published results. Null until at least one result is published for the student.
final studentReportCardProvider = Provider<ExamReportCard?>((ref) {
  final data = ref.watch(studentExamsProvider);
  return ExamReportCardBuilder.fromPublishedResults(
    studentName: data.studentName,
    classLabel: data.classLabel,
    results: [
      // PRA-P0-06 / PRA-P1-32 (S4) — the exams feed is the server's source of
      // truth for PUBLISHED results (unpublished marks never appear here).
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
