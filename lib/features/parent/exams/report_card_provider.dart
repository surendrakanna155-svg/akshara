import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/exams/exam_report_card.dart';
import '../../../core/repositories/mock/mock_attendance_sync_store.dart';
import '../parent_active_child_provider.dart';
import 'parent_exams_provider.dart';

/// Report card for the active child, built from published results (Slice 6).
/// Null until at least one result is published for the child.
final parentReportCardProvider = Provider<ExamReportCard?>((ref) {
  // Re-evaluate whenever the exams future refreshes (publish/unpublish).
  ref.watch(parentExamsFutureProvider);
  final studentId = ref.watch(parentActiveStudentIdProvider);
  final store = ExamAdministrationStore.instance;
  final results = store.resultsForStudent(studentId);
  if (results.isEmpty) return null;
  // Most recently published term.
  final term = results.last.termLabel;
  return ExamReportCardBuilder.build(
    store,
    sisStudentId: studentId,
    termLabel: term,
    attendancePercent: MockAttendanceSyncStore.instance.attendancePercent(),
  );
});
