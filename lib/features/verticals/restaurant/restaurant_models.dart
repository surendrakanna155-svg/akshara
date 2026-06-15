import 'package:flutter/foundation.dart';


@immutable
class RestaurantDashboard {
  const RestaurantDashboard({
    required this.kpis,
    required this.summary,
    required this.generatedAt,
  });

  final List<RestaurantKpi> kpis;
  final String summary;
  final DateTime generatedAt;
}

@immutable
class RestaurantKpi {
  const RestaurantKpi({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}


@immutable
class RestaurantTable {
  const RestaurantTable({
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
class RestaurantOrder {
  const RestaurantOrder({
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
class KitchenTicket {
  const KitchenTicket({
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
class HospitalityIntelligence {
  const HospitalityIntelligence({
    required this.recommendations,
    required this.insights,
    required this.generatedAt,
  });

  final List<String> recommendations;
  final List<String> insights;
  final DateTime generatedAt;
}
