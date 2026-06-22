import 'package:akshara_erp/core/repositories/api/multi_school/api_multi_school_operations_repository.dart';
import 'package:akshara_erp/core/repositories/api/multi_school/remote/multi_school_operations_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/multi_school_operations_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_multi_school_operations_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/platform/multi_school/multi_school_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-school operations repository contract', () {
    late MockMultiSchoolOperationsRepository mockRepo;
    late ApiMultiSchoolOperationsRepository apiRepo;

    setUp(() {
      mockRepo = MockMultiSchoolOperationsRepository();
      apiRepo = ApiMultiSchoolOperationsRepository(
        remote: MultiSchoolOperationsRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement MultiSchoolOperationsRepository', () {
      expect(mockRepo, isA<MultiSchoolOperationsRepository>());
      expect(apiRepo, isA<MultiSchoolOperationsRepository>());
    });

    test('status filtering returns selected lifecycle records', () async {
      final filtered = await mockRepo.listSchools(
        query: RepositoryQuery.demo,
        status: SchoolLifecycleStatus.active,
      );
      expect(filtered, isNotEmpty);
      expect(
        filtered
            .every((school) => school.status == SchoolLifecycleStatus.active),
        isTrue,
      );
    });

    test('dismissAlert removes alert from active list', () async {
      final alerts = await mockRepo.listAlerts(query: RepositoryQuery.demo);
      expect(alerts, isNotEmpty);
      await mockRepo.dismissAlert(
        query: RepositoryQuery.demo,
        alertId: alerts.first.id,
      );
      final refreshed = await mockRepo.listAlerts(query: RepositoryQuery.demo);
      expect(refreshed.any((a) => a.id == alerts.first.id), isFalse);
    });
  });
}
