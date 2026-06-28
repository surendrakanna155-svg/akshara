import 'package:akshara_erp/core/repositories/mock/mock_academic_operations_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW1 · QA-J-038 — student promotion is COMMIT-verified (not preview-only).
/// Drives the academic-operations repository through the real commit path:
/// suggest mappings → preview → execute, and asserts a persisted grade change
/// (executedCount > 0). The full wizard UI is covered separately (QW3/QW7); this
/// closes the row's actual gap — that the year transition can be *committed*.
void main() {
  test('QA-J-038: year-transition preview then execute commits a grade change',
      () async {
    final sis = MockSisRepository();
    final repo = MockAcademicOperationsRepository(sisRepository: sis);
    const query = RepositoryQuery.demo;

    // Derive the source year from a seeded student (avoids en-dash literal
    // mismatches); target year only labels the transition.
    final roster = await sis.getStudents(query: query);
    expect(roster.items, isNotEmpty, reason: 'expected a seeded student roster');
    final sourceYear = roster.items.first.academicYear;
    final targetYear = '$sourceYear+1';

    final mappings = await repo.suggestClassMappings(
      query: query,
      sourceYearId: sourceYear,
      targetYearId: targetYear,
    );
    expect(mappings, isNotEmpty, reason: 'expected suggested class mappings');

    final job = await repo.previewYearTransition(
      query: query,
      sourceYearId: sourceYear,
      targetYearId: targetYear,
      mappings: mappings,
    );
    expect(job.previewRows, isNotEmpty,
        reason: 'preview should list affected students');

    final report = await repo.executeYearTransition(
      query: query,
      jobId: job.id,
    );
    expect(report.executedCount, greaterThan(0),
        reason: 'execute should commit the promotion (students moved)');
  });
}
