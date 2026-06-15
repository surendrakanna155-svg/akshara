import 'package:flutter/foundation.dart';


@immutable
class SalonDashboard {
  const SalonDashboard({
    required this.kpis,
    required this.summary,
    required this.generatedAt,
  });

  final List<SalonKpi> kpis;
  final String summary;
  final DateTime generatedAt;
}

@immutable
class SalonKpi {
  const SalonKpi({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}


@immutable
class SalonCustomer {
  const SalonCustomer({
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
class SalonAppointment {
  const SalonAppointment({
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
class SalonService {
  const SalonService({
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
class SalonIntelligence {
  const SalonIntelligence({
    required this.recommendations,
    required this.insights,
    required this.generatedAt,
  });

  final List<String> recommendations;
  final List<String> insights;
  final DateTime generatedAt;
}
