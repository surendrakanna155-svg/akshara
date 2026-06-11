import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_education_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_distribution_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 20 — Real school simulation journeys (mock repository parity).
void main() {
  group('Real school role journeys (mock)', () {
    const query = RepositoryQuery.demo;
    final admissions = MockAdmissionsRepository();
    final finance = MockFinanceRepository();
    final sis = MockSisRepository();
    final teacher = MockTeacherRepository();
    final parent = MockParentRepository();
    final inventory = MockInventoryRepository();
    final distribution = MockInventoryDistributionRepository();
    final education = MockEducationRepository();
    final school = MockSchoolCompletionRepository();
    final intelligence = MockIntelligenceRepository();

    test('school admin: admission → SIS registry', () async {
      expect((await admissions.getDashboard(query: query)).kpis, isNotEmpty);
      expect((await sis.getStudents(query: query)).total, greaterThan(0));
    });

    test('principal: intelligence + school completion', () async {
      final principal = await intelligence.getPrincipalCenter(query: query);
      expect(principal.schoolHealthScore, greaterThan(0));
      final subjects = await school.listSubjects(query: query);
      expect(subjects, isNotEmpty);
    });

    test('teacher: attendance + homework + lesson logs', () async {
      expect((await teacher.getDashboard(query: query)).pendingTasks, isNotEmpty);
      expect((await teacher.getHomeworkAssignments(query: query)), isNotEmpty);
      final logs = await school.listLessonLogs(query: query);
      expect(logs, isNotEmpty);
    });

    test('parent: fees + homework + attendance', () async {
      expect((await parent.getDashboard(query: query)).childName, isNotEmpty);
      expect((await parent.getFees(query: query)).pendingAmount, greaterThanOrEqualTo(0));
      expect((await parent.getHomework(query: query)).items, isNotEmpty);
      expect((await parent.getAttendance(query: query, month: DateTime(2026, 6, 1))).kpi.attendancePercent, greaterThanOrEqualTo(0));
    });

    test('accountant: finance collections + refunds', () async {
      expect((await finance.getCollections(query: query)).total, greaterThan(0));
      expect((await finance.getRefundRequests(query: query)).total, greaterThan(0));
      expect((await finance.getFinanceExecutiveDashboard(query: query)).collectionHealthScore, greaterThan(0));
    });

    test('inventory manager: stock + book distribution', () async {
      expect((await inventory.getDashboard(query: query)).kpis, isNotEmpty);
      final reports = await distribution.getReports(query: query);
      expect(reports.issued, greaterThanOrEqualTo(0));
    });

    test('education workflows: homework + question papers', () async {
      final homework = await education.listHomework(query: query);
      expect(homework, isNotEmpty);
      final papers = await education.listQuestionPapers(query: query);
      expect(papers, isNotEmpty);
    });
  });
}
