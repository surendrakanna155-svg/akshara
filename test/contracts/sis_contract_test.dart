import 'package:akshara_erp/core/repositories/api/sis/api_sis_repository.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/sis_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/mapper/sis_mapper.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_test_helpers.dart';

void main() {
  group('SIS repository contract', () {
    late MockSisRepository mockRepo;
    late ApiSisRepository apiRepo;

    setUp(() {
      mockRepo = MockSisRepository();
      apiRepo = ApiSisRepository(remote: SisRemoteDataSource(Dio()));
    });

    test('mock and api implement SisRepository', () {
      expect(mockRepo, isA<SisRepository>());
      expect(apiRepo, isA<SisRepository>());
    });

    test('getDashboard signatures match', () {
      expect(
        mockRepo.getDashboard,
        isA<Future<dynamic> Function({required RepositoryQuery query})>(),
      );
      expect(
        apiRepo.getDashboard,
        isA<Future<dynamic> Function({required RepositoryQuery query})>(),
      );
    });

    test('DTO mapping produces compatible dashboard KPIs', () async {
      final mockData = await mockRepo.getDashboard(query: kContractQuery);
      final fixture = SisDashboardDto.fromJson({
        'aiInsight': mockData.aiInsight,
        'kpis': [
          for (final kpi in mockData.kpis)
            kpiJson(
              id: kpi.id,
              value: kpi.value,
              label: kpi.label,
              accentName: kpi.accentName,
              detail: kpi.detail,
            ),
        ],
      });

      final mapped = const SisMapper().toDashboard(fixture);

      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
      expect(
        mapped.kpis.map((k) => k.label).toList(),
        mockData.kpis.map((k) => k.label).toList(),
      );
    });
  });
}
