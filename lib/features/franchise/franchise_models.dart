import 'package:flutter/foundation.dart';

@immutable
class FranchiseEntity {
  const FranchiseEntity({
    required this.id,
    required this.name,
    required this.region,
    required this.schoolCount,
    required this.kpiScore,
  });

  final String id;
  final String name;
  final String region;
  final int schoolCount;
  final int kpiScore;
}

@immutable
class FranchisePortfolioKpi {
  const FranchisePortfolioKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.delta,
  });

  final String id;
  final String label;
  final String value;
  final String delta;
}

@immutable
class FranchiseDashboard {
  const FranchiseDashboard({
    required this.portfolioKpis,
    required this.franchises,
  });

  final List<FranchisePortfolioKpi> portfolioKpis;
  final List<FranchiseEntity> franchises;
}
