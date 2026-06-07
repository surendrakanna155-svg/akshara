import 'package:akshara_erp/core/repositories/api/api_exception.dart';
import 'package:akshara_erp/core/repositories/api/parent/api_parent_repository.dart';
import 'package:akshara_erp/core/repositories/interfaces/parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Parent repository contract', () {
    late MockParentRepository mockRepo;
    late ApiParentRepository apiRepo;

    setUp(() {
      mockRepo = MockParentRepository();
      apiRepo = ApiParentRepository();
    });

    test('mock and api implement ParentRepository', () {
      expect(mockRepo, isA<ParentRepository>());
      expect(apiRepo, isA<ParentRepository>());
    });

    test('getDashboard returns mock dashboard data', () async {
      final data = await mockRepo.getDashboard(query: kQuery);
      expect(data.childName, isNotEmpty);
      expect(data.quickActions, isNotEmpty);
    });

    test('getAttendance returns month data', () async {
      final data = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      expect(data.kpi.attendancePercent, greaterThan(0));
    });

    test('getHomework returns items', () async {
      final data = await mockRepo.getHomework(query: kQuery);
      expect(data.items, isNotEmpty);
    });

    test('getFees returns pending amount', () async {
      final data = await mockRepo.getFees(query: kQuery);
      expect(data.pendingAmount, greaterThan(0));
    });

    test('getReceipts returns fee receipts', () async {
      final receipts = await mockRepo.getReceipts(query: kQuery);
      expect(receipts, isNotEmpty);
    });

    test('getPaymentSummary returns summary for installment', () async {
      final summary = await mockRepo.getPaymentSummary(
        query: kQuery,
        installmentId: 'term_2',
      );
      expect(summary.installmentId, 'term_2');
      expect(summary.totalAmount, greaterThan(0));
    });

    test('api getDashboard throws ApiNotConnectedException', () async {
      await expectLater(
        apiRepo.getDashboard(query: kQuery),
        throwsA(isA<ApiNotConnectedException>()),
      );
    });
  });
}
