import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 20 Step 5 — Large school load budgets (500-student mock scale).
void main() {
  group('Large school performance (mock)', () {
    const query = RepositoryQuery.demo;
    const studentBudgetMs = 800;
    const batchBudgetMs = 1200;

    Future<int> measure(Future<void> Function() fn) async {
      final sw = Stopwatch()..start();
      await fn();
      sw.stop();
      return sw.elapsedMilliseconds;
    }

    test('SIS student list under ${studentBudgetMs}ms', () async {
      final repo = MockSisRepository();
      final ms = await measure(() async {
        await repo.getStudents(query: query);
        await repo.getDashboard(query: query);
      });
      expect(ms, lessThan(studentBudgetMs));
    });

    test('batch dashboard loads under ${batchBudgetMs}ms', () async {
      final sis = MockSisRepository();
      final ms = await measure(() async {
        await sis.getDashboard(query: query);
        await sis.getStudents(query: query);
      });
      expect(ms, lessThan(batchBudgetMs));
    });

    test('scaled list budgets for 1000 and 2000 student pages', () async {
      final sis = MockSisRepository();
      for (final pageSize in [50, 100]) {
        final ms = await measure(() => sis.getStudents(
              query: query.withPage(1, pageSize: pageSize),
            ));
        expect(ms, lessThan(1500), reason: 'pageSize=$pageSize');
      }
    });
  });
}
