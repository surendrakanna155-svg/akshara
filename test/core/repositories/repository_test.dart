import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repository implementations', () {
    test('MockFinanceRepository returns Phase 1 and Phase 2 data', () {
      final repo = MockFinanceRepository();

      expect(repo.getDashboard().kpis, hasLength(6));
      expect(repo.getCollections(), hasLength(6));
      expect(repo.getFeeStructures('2026-27'), isNotEmpty);
      expect(repo.getStudentAccounts(), hasLength(4));
      expect(repo.getInstallmentPlans(), hasLength(4));
      expect(repo.getCollectionDetail('col_1'), isNotNull);
      expect(repo.getDefaultersDashboard().defaulters, isNotEmpty);
      expect(repo.getRefundRequests(), hasLength(3));
      expect(repo.getDiscountsDashboard().scholarships, hasLength(3));
      expect(repo.getReportsData().catalog, hasLength(4));
      expect(repo.getSettings().sections, isNotEmpty);
    });

    test('MockAdmissionsRepository returns admissions data', () {
      final repo = MockAdmissionsRepository();

      expect(repo.getDashboard().kpis, hasLength(6));
      expect(repo.getLeads(), hasLength(7));
      expect(repo.getApplications(), hasLength(6));
      expect(repo.getDocuments(), hasLength(6));
      expect(repo.getPendingEnrollments(), hasLength(3));
      expect(repo.getApprovedHandoffs(), hasLength(3));
      expect(repo.getApprovalQueue(), hasLength(3));
    });

    test('MockSisRepository returns SIS data', () {
      final repo = MockSisRepository();

      expect(repo.getDashboard().kpis, hasLength(6));
      expect(repo.getStudents(), hasLength(5));
      expect(repo.getClassOptions(), isNotEmpty);
      expect(repo.getSectionOptions(), hasLength(4));
    });
  });

  group('Repository providers', () {
    test('providers wire mock implementations', () {
      final container = ProviderContainer();

      expect(container.read(financeRepositoryProvider), isA<MockFinanceRepository>());
      expect(
        container.read(admissionsRepositoryProvider),
        isA<MockAdmissionsRepository>(),
      );
      expect(container.read(sisRepositoryProvider), isA<MockSisRepository>());

      container.dispose();
    });
  });
}
