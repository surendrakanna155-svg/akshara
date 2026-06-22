import '../../../core/repositories/repository_query.dart';
import 'franchise_models.dart';

abstract class FranchiseRepository {
  Future<FranchiseDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<FranchiseEntity> updateFranchiseScore({
    required RepositoryQuery query,
    required String franchiseId,
    required int delta,
  });
}

class MockFranchiseRepository implements FranchiseRepository {
  final List<FranchiseEntity> _franchises = [
    const FranchiseEntity(
      id: 'FR-01',
      name: 'Akshara South Franchise',
      region: 'South',
      schoolCount: 7,
      kpiScore: 88,
    ),
    const FranchiseEntity(
      id: 'FR-02',
      name: 'Akshara West Franchise',
      region: 'West',
      schoolCount: 5,
      kpiScore: 79,
    ),
  ];

  @override
  Future<FranchiseDashboard> getDashboard({
    required RepositoryQuery query,
  }) async {
    return FranchiseDashboard(
      portfolioKpis: const [
        FranchisePortfolioKpi(
          id: 'portfolio_revenue',
          label: 'Portfolio Revenue',
          value: 'INR 522.9L',
          delta: '+10.2% YoY',
        ),
        FranchisePortfolioKpi(
          id: 'portfolio_growth',
          label: 'Average Growth',
          value: '12%',
          delta: '+2.3 pts',
        ),
        FranchisePortfolioKpi(
          id: 'renewal_rate',
          label: 'Renewal Rate',
          value: '95%',
          delta: '+1.1%',
        ),
      ],
      franchises: List<FranchiseEntity>.unmodifiable(_franchises),
    );
  }

  @override
  Future<FranchiseEntity> updateFranchiseScore({
    required RepositoryQuery query,
    required String franchiseId,
    required int delta,
  }) async {
    final index = _franchises.indexWhere((item) => item.id == franchiseId);
    if (index < 0) {
      throw StateError('Franchise not found: $franchiseId');
    }
    final current = _franchises[index];
    final updated = FranchiseEntity(
      id: current.id,
      name: current.name,
      region: current.region,
      schoolCount: current.schoolCount,
      kpiScore: (current.kpiScore + delta).clamp(0, 100),
    );
    _franchises[index] = updated;
    return updated;
  }
}
