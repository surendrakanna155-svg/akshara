import 'package:akshara_erp/core/repositories/api/inventory_finance/api_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/remote/inventory_finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/remote/inventory_finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/inventory_finance/inventory_finance_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = InventoryFinanceFixtureBuilder();

void main() {
  group('InventoryFinance API integration', () {
    late MockInventoryFinanceRepository mockRepo;
    late ApiInventoryFinanceRepository apiRepo;
    late Map<String, dynamic> Function(String path, String method) responseFor;

    setUp(() async {
      mockRepo = MockInventoryFinanceRepository();
      final dashboard = await mockRepo.getReconciliationDashboard(query: kQuery);
      final timeline = await mockRepo.getTimeline(query: kQuery);
      final goodsReceipts = await mockRepo.getGoodsReceipts(query: kQuery);
      final postings = await mockRepo.getPostings(query: kQuery);
      final vendors = await mockRepo.getVendors(query: kQuery);
      final vendorTransactions = await mockRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );

      responseFor = (path, method) {
        if (path == InventoryFinanceApiPaths.reconciliationDashboard) {
          return _fixtures.envelope(_fixtures.dashboardEnvelope(dashboard)['data'] as Map<String, dynamic>);
        }
        if (path == InventoryFinanceApiPaths.reconciliationTimeline) {
          return _fixtures.envelope({'items': _fixtures.timelineItems(timeline)});
        }
        if (path == InventoryFinanceApiPaths.goodsReceipts) {
          return _fixtures.envelope({
            'items': [
              for (final item in goodsReceipts.items)
                _fixtures.goodsReceiptSummaryItem(item),
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.postings) {
          return _fixtures.envelope({
            'items': [
              for (final item in postings.items) _fixtures.postingItem(item),
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.vendorCatalog) {
          return _fixtures.envelope({
            'items': [
              for (final vendor in vendors.items)
                {
                  'id': vendor.id,
                  'vendorCode': vendor.vendorCode,
                  'displayName': vendor.displayName,
                  'contactPhone': vendor.contactPhone,
                  'contactEmail': vendor.contactEmail,
                  'gstin': vendor.gstin,
                  'status': vendor.status,
                },
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.vendorTransactions('vendor_if_1')) {
          return _fixtures.envelope({
            'items': [
              for (final tx in vendorTransactions)
                _fixtures.vendorTransactionItem(tx),
            ],
          });
        }
        throw UnsupportedError('Unhandled path: $method $path');
      };

      final dio = createFakeDio((options) {
        return responseFor(options.path, options.method);
      });

      apiRepo = ApiInventoryFinanceRepository(
        remote: InventoryFinanceRemoteDataSource(dio),
      );
    });

    test('getReconciliationDashboard returns mapped dashboard', () async {
      final mockData = await mockRepo.getReconciliationDashboard(query: kQuery);
      final apiData = await apiRepo.getReconciliationDashboard(query: kQuery);
      expect(apiData.vendorCount, mockData.vendorCount);
      expect(apiData.openApAmount, mockData.openApAmount);
    });

    test('getTimeline returns mapped entries', () async {
      final mockData = await mockRepo.getTimeline(query: kQuery);
      final apiData = await apiRepo.getTimeline(query: kQuery);
      expect(apiData.length, mockData.length);
      expect(apiData.first.label, mockData.first.label);
    });

    test('getGoodsReceipts returns mapped summaries', () async {
      final mockData = await mockRepo.getGoodsReceipts(query: kQuery);
      final apiData = await apiRepo.getGoodsReceipts(query: kQuery);
      expect(apiData.items.length, mockData.items.length);
      expect(apiData.items.first.grnNumber, mockData.items.first.grnNumber);
    });

    test('getPostings returns mapped postings', () async {
      final mockData = await mockRepo.getPostings(query: kQuery);
      final apiData = await apiRepo.getPostings(query: kQuery);
      expect(apiData.items.length, mockData.items.length);
    });

    test('getVendorTransactions returns mapped transactions', () async {
      final mockData = await mockRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );
      final apiData = await apiRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );
      expect(apiData.length, mockData.length);
      expect(apiData.first.referenceNumber, mockData.first.referenceNumber);
    });
  });
}
