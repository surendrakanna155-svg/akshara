import 'package:akshara_erp/core/repositories/api/phase4/api_phase4_repositories.dart';
import 'package:akshara_erp/core/repositories/api/phase4/phase4_mapper.dart';
import 'package:akshara_erp/core/repositories/api/phase4/phase4_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/inventory_distribution_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_distribution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/inventory_distribution/inventory_distribution_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Inventory distribution repository contract', () {
    late MockInventoryDistributionRepository mockRepo;
    late ApiInventoryDistributionRepository apiRepo;

    setUp(() {
      mockRepo = MockInventoryDistributionRepository();
      apiRepo = ApiInventoryDistributionRepository(
        remote: Phase4RemoteDataSource(Dio()),
      );
    });

    test('mock and api implement InventoryDistributionRepository', () {
      expect(mockRepo, isA<InventoryDistributionRepository>());
      expect(apiRepo, isA<InventoryDistributionRepository>());
    });

    test('dashboard mapping parity stays aligned', () async {
      final mockData = await mockRepo.getDashboard(query: _query);
      final mapped = Phase4Mapper.distributionDashboardFromApi({
        'pendingDistributions': mockData.pendingDistributions,
        'replacementRequests': mockData.replacementRequests,
        'paymentPending': mockData.paymentPending,
        'distributedToday': mockData.distributedToday,
        'byCategory': mockData.byCategory,
      });

      expect(mapped.pendingDistributions, mockData.pendingDistributions);
      expect(mapped.byCategory.length, mockData.byCategory.length);
    });

    test('distribution item mapping parity stays aligned', () async {
      final mockData = await mockRepo.listDistributions(query: _query);
      final mapped = mockData
          .map(
            (item) => Phase4Mapper.distributionFromApi(
              _distributionToMap(item),
            ),
          )
          .toList();

      expect(mapped.length, mockData.length);
      expect(mapped.first.id, mockData.first.id);
      expect(mapped.first.status, mockData.first.status);
    });
  });
}

Map<String, dynamic> _distributionToMap(InvStudentDistribution item) {
  return {
    'id': item.id,
    'studentId': item.studentId,
    'catalogItemId': item.catalogItemId,
    'itemName': item.itemName,
    'category': item.category,
    'quantity': item.quantity,
    'status': item.status,
    'distributedAt': item.distributedAt,
    'acknowledgedAt': item.acknowledgedAt,
    'paymentRequestId': item.paymentRequestId,
  };
}
