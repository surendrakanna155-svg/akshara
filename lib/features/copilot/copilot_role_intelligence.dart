import '../../core/security/erp_role.dart';
import '../../router/route_names.dart';
import 'copilot_models.dart';

/// Copilot personas aligned with Akshara intelligence vision.
enum CopilotPersonaRole {
  platformOwner,
  organizationOwner,
  directorCorrespondent,
  principal,
  academicCoordinator,
  teacher,
  parent,
  student,
  finance,
  hr;

  String get label => switch (this) {
        CopilotPersonaRole.platformOwner => 'Platform Owner',
        CopilotPersonaRole.organizationOwner => 'Organization Owner',
        CopilotPersonaRole.directorCorrespondent => 'Director / Correspondent',
        CopilotPersonaRole.principal => 'Principal',
        CopilotPersonaRole.academicCoordinator => 'Academic Coordinator',
        CopilotPersonaRole.teacher => 'Teacher',
        CopilotPersonaRole.parent => 'Parent',
        CopilotPersonaRole.student => 'Student',
        CopilotPersonaRole.finance => 'Finance',
        CopilotPersonaRole.hr => 'HR',
      };

  List<String> get intelligenceFocus => switch (this) {
        CopilotPersonaRole.platformOwner => [
            'school comparison',
            'revenue trends',
            'growth opportunities',
            'expansion recommendations',
          ],
        CopilotPersonaRole.organizationOwner => [
            'multi-school portfolio',
            'trust governance',
            'revenue trends',
            'expansion recommendations',
          ],
        CopilotPersonaRole.directorCorrespondent => [
            'admissions',
            'fee collection',
            'staff performance',
            'school health score',
          ],
        CopilotPersonaRole.principal => [
            'attendance trends',
            'academic performance',
            'teacher effectiveness',
            'at-risk students',
          ],
        CopilotPersonaRole.academicCoordinator => [
            'class performance',
            'timetable conflicts',
            'teacher assignments',
            'at-risk students',
          ],
        CopilotPersonaRole.teacher => [
            'weak students',
            'attendance alerts',
            'homework completion',
            'class insights',
          ],
        CopilotPersonaRole.parent => [
            'child performance',
            'attendance alerts',
            'homework reminders',
          ],
        CopilotPersonaRole.student => [
            'study recommendations',
            'exam preparation',
            'performance insights',
          ],
        CopilotPersonaRole.finance => [
            'fee collection trends',
            'defaulter risk',
            'cashflow planning',
            'reconciliation anomalies',
          ],
        CopilotPersonaRole.hr => [
            'staff attendance',
            'leave compliance',
            'payroll readiness',
            'workforce planning',
          ],
      };

  static CopilotPersonaRole? fromName(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final role in CopilotPersonaRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

CopilotPersonaRole copilotPersonaForErpRole(ErpRole role) => switch (role) {
      ErpRole.superAdmin => CopilotPersonaRole.platformOwner,
      ErpRole.schoolAdmin => CopilotPersonaRole.organizationOwner,
      ErpRole.management => CopilotPersonaRole.directorCorrespondent,
      ErpRole.principal => CopilotPersonaRole.principal,
      ErpRole.admissionsCounselor => CopilotPersonaRole.academicCoordinator,
      ErpRole.financeAdmin => CopilotPersonaRole.finance,
      ErpRole.teacher => CopilotPersonaRole.teacher,
      ErpRole.parent => CopilotPersonaRole.parent,
      ErpRole.student => CopilotPersonaRole.student,
      ErpRole.transportManager ||
      ErpRole.hostelManager ||
      ErpRole.librarian ||
      ErpRole.inventoryManager =>
        CopilotPersonaRole.hr,
    };

CopilotAssistantType defaultAssistantForPersona(CopilotPersonaRole persona) =>
    switch (persona) {
      CopilotPersonaRole.platformOwner ||
      CopilotPersonaRole.organizationOwner ||
      CopilotPersonaRole.principal =>
        CopilotAssistantType.principal,
      CopilotPersonaRole.directorCorrespondent => CopilotAssistantType.finance,
      CopilotPersonaRole.academicCoordinator => CopilotAssistantType.academic,
      CopilotPersonaRole.teacher => CopilotAssistantType.teacher,
      CopilotPersonaRole.parent => CopilotAssistantType.parentGuidance,
      CopilotPersonaRole.student => CopilotAssistantType.academic,
      CopilotPersonaRole.finance => CopilotAssistantType.finance,
      CopilotPersonaRole.hr => CopilotAssistantType.communication,
    };

CopilotAssistantType assistantForRoute(
    String route, CopilotPersonaRole persona) {
  if (route.startsWith(RouteNames.finance)) return CopilotAssistantType.finance;
  if (route.startsWith(RouteNames.managementAdmissions) ||
      route.contains('/admissions')) {
    return CopilotAssistantType.admissions;
  }
  if (route.startsWith(RouteNames.studentSuccessIntelligence) ||
      route.startsWith(RouteNames.examIntelligence)) {
    return CopilotAssistantType.academic;
  }
  if (route.startsWith(RouteNames.controlCenter)) {
    return CopilotAssistantType.principal;
  }
  if (route.startsWith(RouteNames.director)) {
    return CopilotAssistantType.principal;
  }
  if (route.startsWith('/management')) return CopilotAssistantType.principal;
  if (route.startsWith('/sis')) return CopilotAssistantType.sis;
  return defaultAssistantForPersona(persona);
}

String copilotModuleForRoute(String route) {
  if (route.startsWith('/management')) return 'management';
  if (route.startsWith('/finance')) return 'finance';
  if (route.startsWith('/admissions')) return 'admissions';
  if (route.startsWith('/sis')) return 'sis';
  if (route.startsWith('/intelligence')) return 'intelligence';
  if (route.startsWith('/inventory')) return 'inventory';
  if (route.startsWith('/control-center')) return 'control_center';
  if (route.startsWith('/director')) return 'director';
  if (route.startsWith('/transport')) return 'transport';
  if (route.startsWith('/hostel')) return 'hostel';
  if (route.startsWith('/library')) return 'library';
  if (route.startsWith('/hr')) return 'hr';
  if (route.startsWith('/teacher')) return 'teacher';
  if (route.startsWith('/parent')) return 'parent';
  if (route.startsWith('/student')) return 'student';
  if (route.startsWith(RouteNames.copilot)) return 'copilot';
  if (route.startsWith('/admin')) return 'admin';
  return 'general';
}

String copilotScreenLabelForRoute(String route) {
  if (route == RouteNames.managementDashboard) return 'Owner Dashboard';
  if (route == RouteNames.managementAnalytics) return 'Management Analytics';
  if (route == RouteNames.managementAdmissions) return 'Admissions Pipeline';
  if (route == RouteNames.managementAcademics) return 'Academic Health';
  if (route == RouteNames.financeReports) return 'Finance Reports';
  if (route == RouteNames.financeDefaulters) return 'Collection Follow-up';
  if (route == RouteNames.studentSuccessIntelligence) {
    return 'Student Success Intelligence';
  }
  if (route == RouteNames.examIntelligence) return 'Exam Intelligence';
  if (route == RouteNames.controlCenterDashboard) {
    return 'Control Center Dashboard';
  }
  if (route == RouteNames.controlCenterIntelligence) {
    return 'Platform Intelligence';
  }
  if (route == RouteNames.directorDashboard) {
    return 'Director Executive Dashboard';
  }
  if (route == RouteNames.directorReports) {
    return 'Director Strategic Reports';
  }
  if (route == RouteNames.copilot) return 'AI Copilot';
  final segment = route.split('/').where((s) => s.isNotEmpty).lastOrNull;
  if (segment == null || segment.isEmpty) return 'Home';
  return segment
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
