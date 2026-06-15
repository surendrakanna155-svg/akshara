import 'package:flutter/foundation.dart';


@immutable
class AccommodationDashboard {
  const AccommodationDashboard({
    required this.kpis,
    required this.summary,
    required this.generatedAt,
  });

  final List<AccommodationKpi> kpis;
  final String summary;
  final DateTime generatedAt;
}

@immutable
class AccommodationKpi {
  const AccommodationKpi({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}


@immutable
class Resident {
  const Resident({
    required this.id,
    required this.name,
    required this.status,
    this.detail,
  });

  final String id;
  final String name;
  final String status;
  final String? detail;
}


@immutable
class RoomOccupancy {
  const RoomOccupancy({
    required this.id,
    required this.name,
    required this.status,
    this.detail,
  });

  final String id;
  final String name;
  final String status;
  final String? detail;
}


@immutable
class AccommodationAllocation {
  const AccommodationAllocation({
    required this.id,
    required this.name,
    required this.status,
    this.detail,
  });

  final String id;
  final String name;
  final String status;
  final String? detail;
}


@immutable
class AccommodationIntelligence {
  const AccommodationIntelligence({
    required this.recommendations,
    required this.insights,
    required this.generatedAt,
  });

  final List<String> recommendations;
  final List<String> insights;
  final DateTime generatedAt;
}
