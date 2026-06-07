import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cross-module workflow certification for pilot readiness (v5.0).
void main() {
  group('Pilot workflow certification', () {
    const query = RepositoryQuery.demo;

    test('Admissions → Finance handoff data available', () async {
      final admissions = MockAdmissionsRepository();
      final handoffs = await admissions.getApprovedHandoffs(query: query);
      expect(handoffs.total, greaterThan(0));

      final finance = MockFinanceRepository();
      final accounts = await finance.getStudentAccounts(query: query);
      expect(accounts.total, greaterThan(0));
    });

    test('Admissions enrollment pipeline has pending records', () async {
      final admissions = MockAdmissionsRepository();
      final pending = await admissions.getPendingEnrollments(query: query);
      expect(pending.total, greaterThan(0));
      final approval = await admissions.getApprovalQueue(query: query);
      expect(approval.total, greaterThan(0));
    });

    test('SIS student registry available for conversion', () async {
      final sis = MockSisRepository();
      final students = await sis.getStudents(query: query);
      expect(students.total, greaterThan(0));
      final conversion = await sis.getAdmissionsConversion(query: query);
      expect(conversion.queue, isNotEmpty);
    });

    test('Finance collections and refunds readable', () async {
      final finance = MockFinanceRepository();
      expect((await finance.getCollections(query: query)).total, greaterThan(0));
      expect((await finance.getRefundRequests(query: query)).total, greaterThan(0));
    });
  });
}
