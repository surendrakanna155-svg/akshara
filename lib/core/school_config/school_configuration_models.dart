import 'package:flutter/foundation.dart';

/// FV-PLAT-14 — Smart School Discovery & Configuration Engine.

enum SchoolType {
  preschool('preschool', 'Preschool'),
  primary('primary', 'Primary'),
  highSchool('high_school', 'High School'),
  higherSecondary('higher_secondary', 'Higher Secondary'),
  residential('residential', 'Residential'),
  daySchool('day_school', 'Day School');

  const SchoolType(this.storageKey, this.label);
  final String storageKey;
  final String label;

  static SchoolType fromStorageKey(String? key) {
    for (final value in SchoolType.values) {
      if (value.storageKey == key) return value;
    }
    return SchoolType.daySchool;
  }
}

enum SchoolCurriculum {
  cbse('cbse', 'CBSE'),
  icse('icse', 'ICSE'),
  stateBoard('state_board', 'State Board'),
  ib('ib', 'IB'),
  cambridge('cambridge', 'Cambridge'),
  custom('custom', 'Custom');

  const SchoolCurriculum(this.storageKey, this.label);
  final String storageKey;
  final String label;

  static SchoolCurriculum fromStorageKey(String? key) {
    for (final value in SchoolCurriculum.values) {
      if (value.storageKey == key) return value;
    }
    return SchoolCurriculum.cbse;
  }
}

enum SchoolOperationsModel {
  singleSchool('single_school', 'Single School'),
  schoolGroup('school_group', 'School Group'),
  franchise('franchise', 'Franchise'),
  trust('trust', 'Trust / Organization');

  const SchoolOperationsModel(this.storageKey, this.label);
  final String storageKey;
  final String label;

  static SchoolOperationsModel fromStorageKey(String? key) {
    for (final value in SchoolOperationsModel.values) {
      if (value.storageKey == key) return value;
    }
    return SchoolOperationsModel.singleSchool;
  }
}

@immutable
class SchoolCapabilities {
  const SchoolCapabilities({
    this.transport = true,
    this.hostel = true,
    this.library = true,
    this.inventory = true,
    this.alumni = true,
    this.hrPayroll = true,
    this.multiBranch = false,
    this.trustOrganization = false,
  });

  final bool transport;
  final bool hostel;
  final bool library;
  final bool inventory;
  final bool alumni;
  final bool hrPayroll;
  final bool multiBranch;
  final bool trustOrganization;

  SchoolCapabilities copyWith({
    bool? transport,
    bool? hostel,
    bool? library,
    bool? inventory,
    bool? alumni,
    bool? hrPayroll,
    bool? multiBranch,
    bool? trustOrganization,
  }) {
    return SchoolCapabilities(
      transport: transport ?? this.transport,
      hostel: hostel ?? this.hostel,
      library: library ?? this.library,
      inventory: inventory ?? this.inventory,
      alumni: alumni ?? this.alumni,
      hrPayroll: hrPayroll ?? this.hrPayroll,
      multiBranch: multiBranch ?? this.multiBranch,
      trustOrganization: trustOrganization ?? this.trustOrganization,
    );
  }

  Map<String, dynamic> toJson() => {
        'transport': transport,
        'hostel': hostel,
        'library': library,
        'inventory': inventory,
        'alumni': alumni,
        'hrPayroll': hrPayroll,
        'multiBranch': multiBranch,
        'trustOrganization': trustOrganization,
      };

  factory SchoolCapabilities.fromJson(Map<String, dynamic> json) {
    return SchoolCapabilities(
      transport: json['transport'] as bool? ?? true,
      hostel: json['hostel'] as bool? ?? true,
      library: json['library'] as bool? ?? true,
      inventory: json['inventory'] as bool? ?? true,
      alumni: json['alumni'] as bool? ?? true,
      hrPayroll: json['hrPayroll'] as bool? ?? true,
      multiBranch: json['multiBranch'] as bool? ?? false,
      trustOrganization: json['trustOrganization'] as bool? ?? false,
    );
  }
}

@immutable
class SchoolConfiguration {
  const SchoolConfiguration({
    required this.schoolType,
    required this.curriculum,
    required this.capabilities,
    required this.operationsModel,
    this.branchCount = 1,
    this.configuredAt,
  });

  final SchoolType schoolType;
  final SchoolCurriculum curriculum;
  final SchoolCapabilities capabilities;
  final SchoolOperationsModel operationsModel;
  final int branchCount;
  final DateTime? configuredAt;

  /// Demo default — all school ERP modules enabled for existing journeys.
  factory SchoolConfiguration.demoDefault() => SchoolConfiguration(
        schoolType: SchoolType.daySchool,
        curriculum: SchoolCurriculum.cbse,
        capabilities: const SchoolCapabilities(
          multiBranch: true,
          trustOrganization: true,
        ),
        operationsModel: SchoolOperationsModel.trust,
        branchCount: 3,
        configuredAt: DateTime(2026, 1, 1),
      );

  SchoolConfiguration copyWith({
    SchoolType? schoolType,
    SchoolCurriculum? curriculum,
    SchoolCapabilities? capabilities,
    SchoolOperationsModel? operationsModel,
    int? branchCount,
    DateTime? configuredAt,
  }) {
    return SchoolConfiguration(
      schoolType: schoolType ?? this.schoolType,
      curriculum: curriculum ?? this.curriculum,
      capabilities: capabilities ?? this.capabilities,
      operationsModel: operationsModel ?? this.operationsModel,
      branchCount: branchCount ?? this.branchCount,
      configuredAt: configuredAt ?? this.configuredAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'schoolType': schoolType.storageKey,
        'curriculum': curriculum.storageKey,
        'capabilities': capabilities.toJson(),
        'operationsModel': operationsModel.storageKey,
        'branchCount': branchCount,
        'configuredAt': configuredAt?.toIso8601String(),
      };

  factory SchoolConfiguration.fromJson(Map<String, dynamic> json) {
    return SchoolConfiguration(
      schoolType: SchoolType.fromStorageKey(json['schoolType'] as String?),
      curriculum: SchoolCurriculum.fromStorageKey(json['curriculum'] as String?),
      capabilities: SchoolCapabilities.fromJson(
        (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      operationsModel:
          SchoolOperationsModel.fromStorageKey(json['operationsModel'] as String?),
      branchCount: json['branchCount'] as int? ?? 1,
      configuredAt: json['configuredAt'] != null
          ? DateTime.tryParse(json['configuredAt'] as String)
          : null,
    );
  }

  Map<String, String> copilotMetadata() => {
        'school_type': schoolType.label,
        'curriculum': curriculum.label,
        'operations_model': operationsModel.label,
        'branch_count': '$branchCount',
        'transport_enabled': '${capabilities.transport}',
        'hostel_enabled': '${capabilities.hostel}',
        'library_enabled': '${capabilities.library}',
        'inventory_enabled': '${capabilities.inventory}',
        'alumni_enabled': '${capabilities.alumni}',
        'hr_payroll_enabled': '${capabilities.hrPayroll}',
        'multi_branch': '${capabilities.multiBranch}',
        'trust_organization': '${capabilities.trustOrganization}',
      };
}
