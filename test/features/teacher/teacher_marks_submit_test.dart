import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW1 · QA-J-014 — teacher marks-entry WRITE → submit for verification.
/// Drives the teacher repository's real write path: load an exam's marks, save
/// each mark (persisted on re-read), then submit the exam for verification.
/// Closes the gap that the teacher marks WRITE path was untested. (The grid UI
/// is covered under QW3/QW7.)
void main() {
  test('QA-J-014: teacher saves exam marks and submits for verification',
      () async {
    final repo = MockTeacherRepository();
    const query = RepositoryQuery.demo;

    final exams = await repo.getMarksEntryExams(query: query);
    expect(exams, isNotEmpty, reason: 'expected an exam available for marks entry');
    final examId = exams.first.id;

    final marks = await repo.getExamMarks(query: query, examId: examId);
    expect(marks, isNotEmpty, reason: 'expected student mark entries');

    // Enter a valid mark for every student (some flows require a full grid).
    for (final entry in marks) {
      final value = (entry.maxMarks * 0.75).round();
      final updated = await repo.updateExamMark(
        query: query,
        request: TeacherExamMarkUpdateRequest(
          markEntryId: entry.id,
          marksObtained: value,
        ),
      );
      expect(updated.marksObtained, value, reason: 'mark should be saved');
    }

    // Persistence: re-read shows every mark recorded.
    final reread = await repo.getExamMarks(query: query, examId: examId);
    expect(reread.every((e) => e.marksObtained != null), isTrue,
        reason: 'all marks should persist after save');

    // Submit for verification (teacher → principal pending).
    final result = await repo.processExamResults(
      query: query,
      request: TeacherExamProcessResultsRequest(examId: examId),
    );
    expect(result.examId, examId);
    expect(result.phaseLabel, isNotEmpty,
        reason: 'submit-for-verification should report a phase');
  });
}
