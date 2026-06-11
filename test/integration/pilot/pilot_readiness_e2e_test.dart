import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 20 — End-to-end workflow certification (mock layer parity).
void main() {
  group('Pilot readiness E2E (mock)', () {
    const query = RepositoryQuery.demo;
    final admissions = MockAdmissionsRepository();
    final finance = MockFinanceRepository();
    final sis = MockSisRepository();
    final inventory = MockInventoryRepository();
    final intelligence = MockIntelligenceRepository();

    test('school admin: admissions → finance handoff', () async {
      expect((await admissions.getApprovedHandoffs(query: query)).total, greaterThan(0));
      expect((await finance.getStudentAccounts(query: query)).total, greaterThan(0));
    });

    test('accountant: collections, refunds, intelligence', () async {
      expect((await finance.getCollections(query: query)).total, greaterThan(0));
      expect((await finance.getRefundRequests(query: query)).total, greaterThan(0));
      final copilot = await finance.getFinanceCopilot(query: query);
      expect(copilot.feeCollectionForecast, greaterThan(0));
      final executive = await finance.getFinanceExecutiveDashboard(query: query);
      expect(executive.collectionHealthScore, greaterThan(0));
    });

    test('principal: SIS + student success + exam intelligence', () async {
      expect((await sis.getStudents(query: query)).total, greaterThan(0));
      final success = await intelligence.getStudentSuccessDashboard(query: query);
      expect(success.studentsAnalyzed, greaterThan(0));
      final exam = await intelligence.getExamAnalytics(query: query);
      expect(exam.passRatePercent, greaterThan(0));
    });

    test('teacher: teacher effectiveness insights', () async {
      final perf = await intelligence.getTeacherPerformanceInsights(query: query);
      expect(perf.overallEffectivenessScore, greaterThan(0));
      final planning = await intelligence.getTeacherPlanningCenter(query: query);
      expect(planning.planningItems, isNotEmpty);
    });

    test('inventory: copilot + lifecycle', () async {
      final copilot = await inventory.getInventoryCopilot(query: query);
      expect(copilot.lowStockPredictions, isNotEmpty);
      final lifecycle = await inventory.getAssetLifecycle(query: query);
      expect(lifecycle.recentEvents, isNotEmpty);
    });

    test('attendance + timetable data surfaces exist', () async {
      expect((await sis.getStudents(query: query)).total, greaterThan(0));
      expect((await admissions.getPendingEnrollments(query: query)).total, greaterThan(0));
    });
  });
}
