import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/copilot_screen_context.dart';
import 'package:akshara_erp/features/copilot/copilot_stub_responses.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('copilotPersonaForErpRole', () {
    test('maps expanded personas from ERP roles', () {
      expect(
        copilotPersonaForErpRole(ErpRole.superAdmin),
        CopilotPersonaRole.platformOwner,
      );
      expect(
        copilotPersonaForErpRole(ErpRole.schoolAdmin),
        CopilotPersonaRole.organizationOwner,
      );
      expect(
        copilotPersonaForErpRole(ErpRole.management),
        CopilotPersonaRole.directorCorrespondent,
      );
      expect(
        copilotPersonaForErpRole(ErpRole.principal),
        CopilotPersonaRole.principal,
      );
      expect(
        copilotPersonaForErpRole(ErpRole.admissionsCounselor),
        CopilotPersonaRole.academicCoordinator,
      );
      expect(
        copilotPersonaForErpRole(ErpRole.financeAdmin),
        CopilotPersonaRole.finance,
      );
      expect(copilotPersonaForErpRole(ErpRole.teacher),
          CopilotPersonaRole.teacher);
      expect(
          copilotPersonaForErpRole(ErpRole.parent), CopilotPersonaRole.parent);
      expect(copilotPersonaForErpRole(ErpRole.student),
          CopilotPersonaRole.student);
      expect(
        copilotPersonaForErpRole(ErpRole.inventoryManager),
        CopilotPersonaRole.hr,
      );
    });
  });

  group('route intelligence helpers', () {
    test('derives module and screen labels from ERP routes', () {
      expect(
        copilotModuleForRoute(RouteNames.managementDashboard),
        'management',
      );
      expect(
        copilotScreenLabelForRoute(RouteNames.managementDashboard),
        'Owner Dashboard',
      );
      expect(
        assistantForRoute(
          RouteNames.financeDefaulters,
          CopilotPersonaRole.directorCorrespondent,
        ),
        CopilotAssistantType.finance,
      );
    });
  });

  group('CopilotScreenContext serialization', () {
    test('round-trips JSON for API screenContext payload', () {
      const original = CopilotScreenContext(
        personaRole: CopilotPersonaRole.platformOwner,
        erpRole: ErpRole.superAdmin,
        schoolId: 'school_001',
        organizationId: 'org_001',
        tenantId: 'tenant_001',
        module: 'management',
        route: RouteNames.managementDashboard,
        screen: 'Owner Dashboard',
        filters: {'period': 'Q1'},
        kpis: [
          CopilotKpiSnapshot(
              id: 'revenue_mtd', label: 'Revenue (MTD)', value: '₹1.2Cr'),
        ],
        records: {'approvalQueue': '7'},
      );

      final restored = CopilotScreenContext.fromJson(original.toJson());
      expect(restored.personaRole, original.personaRole);
      expect(restored.module, 'management');
      expect(restored.kpis.first.value, '₹1.2Cr');
      expect(restored.records['approvalQueue'], '7');
    });
  });

  group('buildContextAwareStubReply', () {
    test('includes persona and KPI context in mock response', () {
      const ctx = CopilotScreenContext(
        personaRole: CopilotPersonaRole.principal,
        erpRole: ErpRole.principal,
        schoolId: 'school_001',
        organizationId: 'org_001',
        tenantId: 'tenant_001',
        module: 'management',
        route: RouteNames.managementDashboard,
        screen: 'Owner Dashboard',
        kpis: [
          CopilotKpiSnapshot(
              id: 'attendance', label: 'Attendance', value: '94%'),
        ],
      );

      final reply = buildContextAwareStubReply(
        userMessage: 'Summarize at-risk students',
        screenContext: ctx,
      );

      expect(reply, contains('Principal'));
      expect(reply, contains('Owner Dashboard'));
      expect(reply, contains('Attendance: 94%'));
      expect(reply, contains('at-risk students'));
    });
  });
}
