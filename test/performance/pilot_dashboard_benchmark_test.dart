import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 21 — Dashboard load time budgets (mock repository, local gate).
void main() {
  group('Pilot performance budgets (mock)', () {
    const query = RepositoryQuery.demo;
    const budgetMs = 500;

    Future<int> measure(Future<void> Function() fn) async {
      final sw = Stopwatch()..start();
      await fn();
      sw.stop();
      return sw.elapsedMilliseconds;
    }

    test('finance executive dashboard under ${budgetMs}ms', () async {
      final repo = MockFinanceRepository();
      final ms = await measure(() async {
        await repo.getFinanceExecutiveDashboard(query: query);
        await repo.getFinanceCopilot(query: query);
        await repo.getDashboard(query: query);
      });
      expect(ms, lessThan(budgetMs));
    });

    test('inventory copilot under ${budgetMs}ms', () async {
      final repo = MockInventoryRepository();
      final ms = await measure(() async {
        await repo.getInventoryCopilot(query: query);
        await repo.getDashboard(query: query);
      });
      expect(ms, lessThan(budgetMs));
    });

    test('intelligence dashboards under ${budgetMs}ms', () async {
      final repo = MockIntelligenceRepository();
      final ms = await measure(() async {
        await repo.getStudentSuccessDashboard(query: query);
        await repo.getExamAnalytics(query: query);
        await repo.getTeacherPerformanceInsights(query: query);
      });
      expect(ms, lessThan(budgetMs));
    });

    test('student 360 / SIS under ${budgetMs}ms', () async {
      final repo = MockSisRepository();
      final ms = await measure(() async {
        await repo.getStudents(query: query);
        await repo.getDashboard(query: query);
      });
      expect(ms, lessThan(budgetMs));
    });
  });
}
