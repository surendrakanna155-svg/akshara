import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/platform/franchise/franchise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('franchise dashboard and score update', () async {
    final repo = MockFranchiseRepository();
    final dashboard = await repo.getDashboard(query: RepositoryQuery.demo);
    expect(dashboard.portfolioKpis, isNotEmpty);

    final first = dashboard.franchises.first;
    final updated = await repo.updateFranchiseScore(
      query: RepositoryQuery.demo,
      franchiseId: first.id,
      delta: 2,
    );
    expect(updated.kpiScore, greaterThan(first.kpiScore));
  });
}
