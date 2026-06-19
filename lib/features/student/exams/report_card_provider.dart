import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/exams/exam_report_card.dart';
import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import 'student_exams_provider.dart';

/// Report card for the logged-in student, built from published results (Slice 6).
/// Null until at least one result is published for the student.
final studentReportCardProvider = Provider<ExamReportCard?>((ref) {
  ref.watch(studentExamsFutureProvider); // refresh on publish/unpublish
  final studentId = MockCanonicalStudentRegistry.primaryMobileStudentId;
  final store = ExamAdministrationStore.instance;
  final results = store.resultsForStudent(studentId);
  if (results.isEmpty) return null;
  final term = results.last.termLabel;
  return ExamReportCardBuilder.build(
    store,
    sisStudentId: studentId,
    termLabel: term,
  );
});
