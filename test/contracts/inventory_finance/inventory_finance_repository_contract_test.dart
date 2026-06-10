import 'package:akshara_erp/core/repositories/api/inventory_finance/api_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/dto/inventory_finance_dto.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/mapper/inventory_finance_mapper.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/remote/inventory_finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_finance_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = InventoryFinanceFixtureBuilder();
const _mapper = InventoryFinanceMapper();

void main() {
  group('InventoryFinance repository contract', () {
    late MockInventoryFinanceRepository mockRepo;
    late ApiInventoryFinanceRepository apiRepo;

    setUp(() {
      mockRepo = MockInventoryFinanceRepository();
      apiRepo = ApiInventoryFinanceRepository(
        remote: InventoryFinanceRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement InventoryFinanceRepository', () {
      expect(mockRepo, isA<InventoryFinanceRepository>());
      expect(apiRepo, isA<InventoryFinanceRepository>());
    });

    test('reconciliation dashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReconciliationDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        InventoryFinanceDashboardDto.fromJson(
          _fixtures.dashboardEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.vendorCount, mockData.vendorCount);
      expect(mapped.openApAmount, mockData.openApAmount);
      expect(mapped.inventoryValue, mockData.inventoryValue);
    });

    test('timeline DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTimeline(query: kQuery);
      final mapped = _mapper.toTimeline(
        _fixtures.timelineItems(mockData)
            .map(InventoryFinanceTimelineItemDto.fromJson)
            .toList(),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.label, mockData.first.label);
    });

    test('goods receipts DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getGoodsReceipts(query: kQuery);
      final mapped = _mapper.toGoodsReceiptSummaries(
        mockData.items
            .map(
              (item) => InventoryFinanceGoodsReceiptSummaryDto.fromJson(
                _fixtures.goodsReceiptSummaryItem(item),
              ),
            )
            .toList(),
      );
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.grnNumber, mockData.items.first.grnNumber);
    });

    test('postings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getPostings(query: kQuery);
      final mapped = _mapper.toPostings(
        mockData.items
            .map(
              (item) => InventoryFinancePostingDto.fromJson(
                _fixtures.postingItem(item),
              ),
            )
            .toList(),
      );
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.commitmentNumber, mockData.items.first.commitmentNumber);
    });

    test('vendor transactions DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );
      final mapped = _mapper.toVendorTransactions(
        mockData
            .map(
              (item) => InventoryFinanceVendorTransactionDto.fromJson(
                _fixtures.vendorTransactionItem(item),
              ),
            )
            .toList(),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.referenceNumber, mockData.first.referenceNumber);
    });
  });
}
