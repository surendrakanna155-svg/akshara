import 'package:akshara_erp/features/parent/receipts/parent_receipts_provider.dart';
import 'package:akshara_erp/features/parent/receipts/receipt_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentReceiptsProvider', () {
    test('returns mock receipts list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(parentReceiptsDataProvider);

      expect(data.receipts, isNotEmpty);
      expect(data.childName, 'Ravi Kumar');
    });

    test('filters receipts by category', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentReceiptFilterProvider.notifier).state =
          ReceiptFilter.transport;
      final items = container.read(parentReceiptsListProvider);

      expect(items, isNotEmpty);
      expect(items.every((item) => item.category == 'transport'), isTrue);
    });

    test('search filters by receipt number', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentReceiptSearchProvider.notifier).state = 'ADM';
      final items = container.read(parentReceiptsListProvider);

      expect(items.length, 1);
      expect(items.first.title, 'Admission fee');
    });

    test('parentReceiptDetailProvider resolves receipt by id', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final receipt = container.read(parentReceiptDetailProvider('rcpt_term_1'));

      expect(receipt, isNotNull);
      expect(receipt!.receiptNumber, 'APS-2026-TERM_1');
    });
  });
}
