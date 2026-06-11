import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockFinanceRepository();

  test('finance copilot returns forecast and defaulter predictions', () async {
    final data = await repo.getFinanceCopilot(query: query);
    expect(data.feeCollectionForecast, greaterThan(0));
    expect(data.defaulterPredictions, isNotEmpty);
    expect(data.collectionTrend, isNotEmpty);
  });

  test('finance executive dashboard returns health score', () async {
    final data = await repo.getFinanceExecutiveDashboard(query: query);
    expect(data.collectionHealthScore, greaterThan(0));
    expect(data.riskStudents, isNotEmpty);
  });
}
