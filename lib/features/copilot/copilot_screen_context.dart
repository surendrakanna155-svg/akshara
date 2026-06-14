import 'package:flutter/foundation.dart';

import '../../core/security/erp_role.dart';
import 'copilot_models.dart';
import 'copilot_role_intelligence.dart';

/// Snapshot of ERP UI state sent with each copilot message (INTEL-03).
@immutable
class CopilotKpiSnapshot {
  const CopilotKpiSnapshot({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
      };

  factory CopilotKpiSnapshot.fromJson(Map<String, dynamic> json) {
    return CopilotKpiSnapshot(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

@immutable
class CopilotScreenContext {
  const CopilotScreenContext({
    required this.personaRole,
    required this.erpRole,
    required this.schoolId,
    required this.organizationId,
    required this.tenantId,
    required this.module,
    required this.route,
    required this.screen,
    this.schoolName,
    this.filters = const {},
    this.kpis = const [],
    this.records = const {},
    this.originRoute,
    this.activeChildId,
    this.suggestedAssistant,
  });

  final CopilotPersonaRole personaRole;
  final ErpRole erpRole;
  final String schoolId;
  final String organizationId;
  final String tenantId;
  final String module;
  final String route;
  final String screen;
  final String? schoolName;
  final Map<String, String> filters;
  final List<CopilotKpiSnapshot> kpis;
  final Map<String, String> records;
  final String? originRoute;
  final String? activeChildId;
  final CopilotAssistantType? suggestedAssistant;

  CopilotScreenContext copyWith({
    CopilotPersonaRole? personaRole,
    ErpRole? erpRole,
    String? schoolId,
    String? organizationId,
    String? tenantId,
    String? module,
    String? route,
    String? screen,
    String? schoolName,
    Map<String, String>? filters,
    List<CopilotKpiSnapshot>? kpis,
    Map<String, String>? records,
    String? originRoute,
    String? activeChildId,
    CopilotAssistantType? suggestedAssistant,
  }) {
    return CopilotScreenContext(
      personaRole: personaRole ?? this.personaRole,
      erpRole: erpRole ?? this.erpRole,
      schoolId: schoolId ?? this.schoolId,
      organizationId: organizationId ?? this.organizationId,
      tenantId: tenantId ?? this.tenantId,
      module: module ?? this.module,
      route: route ?? this.route,
      screen: screen ?? this.screen,
      schoolName: schoolName ?? this.schoolName,
      filters: filters ?? this.filters,
      kpis: kpis ?? this.kpis,
      records: records ?? this.records,
      originRoute: originRoute ?? this.originRoute,
      activeChildId: activeChildId ?? this.activeChildId,
      suggestedAssistant: suggestedAssistant ?? this.suggestedAssistant,
    );
  }

  Map<String, dynamic> toJson() => {
        'personaRole': personaRole.name,
        'erpRole': erpRole.name,
        'schoolId': schoolId,
        'organizationId': organizationId,
        'tenantId': tenantId,
        'module': module,
        'route': route,
        'screen': screen,
        if (schoolName != null) 'schoolName': schoolName,
        if (originRoute != null) 'originRoute': originRoute,
        if (activeChildId != null) 'activeChildId': activeChildId,
        if (suggestedAssistant != null) 'suggestedAssistant': suggestedAssistant!.name,
        'filters': filters,
        'kpis': kpis.map((k) => k.toJson()).toList(),
        'records': records,
        'intelligenceFocus': personaRole.intelligenceFocus,
      };

  factory CopilotScreenContext.fromJson(Map<String, dynamic> json) {
    final kpiItems = json['kpis'] as List<dynamic>? ?? const [];
    return CopilotScreenContext(
      personaRole: CopilotPersonaRole.fromName(json['personaRole'] as String?) ??
          CopilotPersonaRole.directorCorrespondent,
      erpRole: ErpRole.fromName(json['erpRole'] as String?) ?? ErpRole.management,
      schoolId: json['schoolId'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      module: json['module'] as String? ?? 'general',
      route: json['route'] as String? ?? '/',
      screen: json['screen'] as String? ?? 'Unknown',
      schoolName: json['schoolName'] as String?,
      originRoute: json['originRoute'] as String?,
      activeChildId: json['activeChildId'] as String?,
      suggestedAssistant: CopilotAssistantType.fromApi(
        json['suggestedAssistant'] as String? ?? '',
      ),
      filters: (json['filters'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      kpis: kpiItems
          .map((item) => CopilotKpiSnapshot.fromJson(item as Map<String, dynamic>))
          .toList(),
      records: (json['records'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
    );
  }

  String get displaySummary =>
      '${personaRole.label} · $screen · ${module.toUpperCase()}';
}
