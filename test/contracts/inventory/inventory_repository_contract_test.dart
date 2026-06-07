import 'package:akshara_erp/core/repositories/api/inventory/api_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/api/inventory/dto/inventory_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/inventory/mapper/inventory_mapper.dart';
import 'package:akshara_erp/core/repositories/api/inventory/remote/inventory_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/inventory_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = InventoryFixtureBuilder();
const _mapper = InventoryMapper();

void main() {
  group('Inventory repository contract', () {
    late MockInventoryRepository mockRepo;
    late ApiInventoryRepository apiRepo;

    setUp(() {
      mockRepo = MockInventoryRepository();
      apiRepo = ApiInventoryRepository(
        remote: InventoryRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement InventoryRepository', () {
      expect(mockRepo, isA<InventoryRepository>());
      expect(apiRepo, isA<InventoryRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        InventoryDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getAssets DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAssets(query: kQuery);
      final mapped = _mapper.toAssets(
        InventoryAssetsResponseDto.fromJson(_fixtures.assetsEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.assetTag, mockData.first.assetTag);
    });

    test('getCategories DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCategories(query: kQuery);
      final mapped = _mapper.toCategories(
        InventoryCategoriesResponseDto.fromJson(
          _fixtures.categoriesEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getAllocations DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAllocations(query: kQuery);
      final mapped = _mapper.toAllocations(
        InventoryAllocationsResponseDto.fromJson(
          _fixtures.allocationsEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getMaintenanceRecords DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getMaintenanceRecords(query: kQuery);
      final mapped = _mapper.toMaintenanceRecords(
        InventoryMaintenanceResponseDto.fromJson(
          _fixtures.maintenanceEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getProcurementOrders DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getProcurementOrders(query: kQuery);
      final mapped = _mapper.toProcurementOrders(
        InventoryProcurementResponseDto.fromJson(
          _fixtures.procurementEnvelope(mockData),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getVendors DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getVendors(query: kQuery);
      final mapped = _mapper.toVendors(
        InventoryVendorsResponseDto.fromJson(_fixtures.vendorsEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = _mapper.toReports(
        InventoryReportsResponseDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );
      expect(mapped.catalog.length, mockData.catalog.length);
    });
  });
}
