import 'package:akshara_erp/features/finance/collection_detail/finance_collection_detail_provider.dart';
import 'package:akshara_erp/features/finance/defaulters/finance_defaulters_provider.dart';
import 'package:akshara_erp/features/finance/discounts/finance_discounts_provider.dart';
import 'package:akshara_erp/features/finance/refunds/finance_refunds_provider.dart';
import 'package:akshara_erp/features/finance/reports/finance_reports_provider.dart';
import 'package:akshara_erp/features/finance/settings/finance_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Finance Phase 2 providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('financeCollectionDetailProvider returns detail for col_1', () {
      final detail = container.read(financeCollectionDetailProvider('col_1'));
      expect(detail, isNotNull);
      expect(detail!.payment.receiptNumber, 'RCP-2026-8841');
      expect(detail.paymentTimeline, isNotEmpty);
    });

    test('financeCollectionDetailProvider returns null when loading', () {
      container = ProviderContainer(
        overrides: [
          financeCollectionDetailLoadingProvider.overrideWith((ref) => true),
        ],
      );
      expect(container.read(financeCollectionDetailProvider('col_1')), isNull);
    });

    test('financeDefaultersProvider returns dashboard data', () {
      final data = container.read(financeDefaultersProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(4));
      expect(data.agingBuckets, hasLength(5));
    });

    test('financeDefaultersProvider returns null on error', () {
      container = ProviderContainer(
        overrides: [
          financeDefaultersErrorProvider.overrideWith((ref) => true),
        ],
      );
      expect(container.read(financeDefaultersProvider), isNull);
    });

    test('financeFilteredDefaultersProvider filters by bucket', () {
      container = ProviderContainer(
        overrides: [
          financeDefaultersFilterProvider.overrideWith((ref) => 3),
        ],
      );
      final filtered = container.read(financeFilteredDefaultersProvider);
      expect(filtered.every((d) => d.daysOverdue >= 90), isTrue);
    });

    test('financeRefundsProvider returns refund queue', () {
      expect(container.read(financeRefundsProvider), hasLength(3));
    });

    test('financeRefundsProvider returns empty when empty flag set', () {
      container = ProviderContainer(
        overrides: [
          financeRefundsEmptyProvider.overrideWith((ref) => true),
        ],
      );
      expect(container.read(financeRefundsProvider), isEmpty);
    });

    test('financeDiscountsProvider returns discounts dashboard', () {
      final data = container.read(financeDiscountsProvider);
      expect(data, isNotNull);
      expect(data!.scholarships, hasLength(3));
    });

    test('financeReportsProvider returns reports data', () {
      final data = container.read(financeReportsProvider);
      expect(data, isNotNull);
      expect(data!.catalog, hasLength(4));
    });

    test('financeSettingsProvider returns settings sections', () {
      final data = container.read(financeSettingsProvider);
      expect(data, isNotNull);
      expect(data!.sections.length, greaterThanOrEqualTo(5));
    });
  });
}
