import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockParentRepository();

  test('parent academic summary includes structured fields', () async {
    final summary = await repo.getAcademicSummary(query: query, studentId: 'student_1');
    expect(summary.attendanceSummary['ratePercent'], isNotNull);
    expect(summary.strengths, isNotEmpty);
    expect(summary.teacherRecommendations, isNotEmpty);
  });

  test('printable report renders summary text', () async {
    final report = await repo.getPrintableReport(query: query, studentId: 'student_1');
    expect(report.contains('Attendance'), isTrue);
  });
}
