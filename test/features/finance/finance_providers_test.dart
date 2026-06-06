import 'package:akshara_erp/features/finance/collections/finance_collections_provider.dart';
import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_provider.dart';
import 'package:akshara_erp/features/finance/fee_structures/finance_fee_structures_provider.dart';
import 'package:akshara_erp/features/finance/integration/finance_admissions_handoff_provider.dart';
import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('financeDashboardProvider', () {
    test('exposes KPIs, trend, and recent payments', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(financeDashboardProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.collectionTrend, hasLength(6));
      expect(data.recentPayments, isNotEmpty);
      expect(data.aiInsight, isNotEmpty);
    });

    test('returns null when loading', () {
      final container = ProviderContainer(
        overrides: [
          financeDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(financeDashboardProvider), isNull);
    });
  });

  group('financeFeeStructuresProvider', () {
    test('exposes active structures for academic year', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final structures = container.read(financeFeeStructuresProvider);
      expect(structures, isNotEmpty);
      expect(structures.first.categories, isNotEmpty);
    });

    test('returns empty when error flag set', () {
      final container = ProviderContainer(
        overrides: [
          financeFeeStructuresErrorProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(financeFeeStructuresProvider), isEmpty);
    });
  });

  group('financeStudentAccountsProvider', () {
    test('exposes mock student fee accounts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final accounts = container.read(financeStudentAccountsProvider);
      expect(accounts, hasLength(4));
      expect(accounts.first.admissionNumber, startsWith('ADM-'));
    });

    test('filters by admission number search', () {
      final container = ProviderContainer(
        overrides: [
          financeStudentSearchQueryProvider.overrideWith(
            (ref) => 'ADM-2026-0138',
          ),
        ],
      );
      addTearDown(container.dispose);

      final filtered = container.read(financeFilteredStudentAccountsProvider);
      expect(filtered, hasLength(1));
      expect(filtered.first.studentName, 'Arjun Patel');
    });
  });

  group('financeHandoffQueueProvider', () {
    test('includes admissions handoff mock data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(financeHandoffQueueProvider);
      expect(queue, hasLength(3));
      expect(queue.first.handoff.studentName, 'Arjun Patel');
    });

    test('pending handoffs excludes completed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pending = container.read(financePendingHandoffsProvider);
      expect(pending.length, lessThan(3));
    });
  });

  group('financeCollectionsProvider', () {
    test('exposes payments and daily summary', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final payments = container.read(financeCollectionsProvider);
      final summary = container.read(financeDailySummaryProvider);

      expect(payments, hasLength(6));
      expect(summary.transactionCount, greaterThan(0));
    });

    test('filters completed payments', () {
      final container = ProviderContainer(
        overrides: [
          financeCollectionFilterProvider.overrideWith((ref) => 1),
        ],
      );
      addTearDown(container.dispose);

      final filtered = container.read(financeFilteredCollectionsProvider);
      expect(
        filtered.every((p) => p.status.name == 'completed'),
        isTrue,
      );
    });
  });
}
