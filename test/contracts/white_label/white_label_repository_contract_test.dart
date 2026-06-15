import 'package:akshara_erp/core/repositories/api/white_label/api_white_label_platform_repository.dart';
import 'package:akshara_erp/core/repositories/api/white_label/remote/white_label_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/white_label_platform_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_white_label_platform_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('White label repository contract', () {
    late MockWhiteLabelPlatformRepository mockRepo;
    late ApiWhiteLabelPlatformRepository apiRepo;

    setUp(() {
      mockRepo = MockWhiteLabelPlatformRepository();
      apiRepo = ApiWhiteLabelPlatformRepository(
        remote: WhiteLabelRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement WhiteLabelPlatformRepository', () {
      expect(mockRepo, isA<WhiteLabelPlatformRepository>());
      expect(apiRepo, isA<WhiteLabelPlatformRepository>());
    });

    test('getDashboard returns profiles', () async {
      final dashboard = await mockRepo.getDashboard(query: RepositoryQuery.demo);
      expect(dashboard.profiles, isNotEmpty);
    });
  });
}
