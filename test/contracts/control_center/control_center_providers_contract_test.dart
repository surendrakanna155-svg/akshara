import 'package:akshara_erp/core/repositories/mock/mock_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockControlCenterRepository();

  test('control center providers returns usage and feature enablements', () async {
    final data = await repo.getProviders(query: query);
    expect(data.providers.length, greaterThanOrEqualTo(3));
    expect(data.usage.totalEvents, greaterThan(0));
    expect(data.features, isNotEmpty);
  });
}
