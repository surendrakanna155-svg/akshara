import 'package:flutter/foundation.dart';


@immutable
class HealthcareDashboard {
  const HealthcareDashboard({
    required this.kpis,
    required this.summary,
    required this.generatedAt,
  });

  final List<HealthcareKpi> kpis;
  final String summary;
  final DateTime generatedAt;
}

@immutable
class HealthcareKpi {
  const HealthcareKpi({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}


@immutable
class Patient {
  const Patient({
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
class Appointment {
  const Appointment({
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
class Practitioner {
  const Practitioner({
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
class HealthcareIntelligence {
  const HealthcareIntelligence({
    required this.recommendations,
    required this.insights,
    required this.generatedAt,
  });

  final List<String> recommendations;
  final List<String> insights;
  final DateTime generatedAt;
}
