import 'package:akshara_erp/features/parent/receipts/parent_receipts_provider.dart';
import 'package:akshara_erp/features/parent/receipts/receipt_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentReceiptsProvider', () {
    test('returns mock receipts list', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentReceiptsFutureProvider.future);
      final data = container.read(parentReceiptsDataProvider);

      expect(data.receipts, isNotEmpty);
      expect(data.childName, 'Ravi Kumar');
    });

    test('filters receipts by category', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentReceiptsFutureProvider.future);
      container.read(parentReceiptFilterProvider.notifier).state =
          ReceiptFilter.transport;
      final items = container.read(parentReceiptsListProvider);

      expect(items, isNotEmpty);
      expect(items.every((item) => item.category == 'transport'), isTrue);
    });

    test('search filters by receipt number', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentReceiptsFutureProvider.future);
      container.read(parentReceiptSearchProvider.notifier).state = 'ADM';
      final items = container.read(parentReceiptsListProvider);

      expect(items.length, 1);
      expect(items.first.title, 'Admission fee');
    });

    test('parentReceiptDetailProvider resolves receipt by id', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentReceiptsFutureProvider.future);
      final receipt = container.read(parentReceiptDetailProvider('rcpt_term_1'));

      expect(receipt, isNotNull);
      expect(receipt!.receiptNumber, 'APS-2026-TERM_1');
    });
  });
}
