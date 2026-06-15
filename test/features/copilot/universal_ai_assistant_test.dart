import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/copilot_screen_context.dart';
import 'package:akshara_erp/features/copilot/universal/universal_ai_assistant_service.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UniversalAiAssistantService', () {
    const service = UniversalAiAssistantService();

    test('resolves finance and hr universal roles', () {
      final finance = service.resolveRole(UniversalAiAssistantRole.finance);
      final hr = service.resolveRole(UniversalAiAssistantRole.hr);

      expect(finance.persona, CopilotPersonaRole.finance);
      expect(finance.assistantType, CopilotAssistantType.finance);
      expect(
        finance.systemPromptSpecialization.toLowerCase(),
        contains('collection'),
      );

      expect(hr.persona, CopilotPersonaRole.hr);
      expect(hr.assistantType, CopilotAssistantType.communication);
      expect(
          hr.systemPromptSpecialization.toLowerCase(), contains('workforce'));
    });

    test('resolves from ERP role mapping', () {
      final financeProfile = service.resolveFromErpRole(ErpRole.financeAdmin);
      final inventoryProfile =
          service.resolveFromErpRole(ErpRole.inventoryManager);

      expect(financeProfile.persona, CopilotPersonaRole.finance);
      expect(inventoryProfile.persona, CopilotPersonaRole.hr);
    });

    test('builds role-specific system prompt with screen context', () {
      const profile = UniversalAiAssistantProfile(
        role: UniversalAiAssistantRole.principal,
        persona: CopilotPersonaRole.principal,
        assistantType: CopilotAssistantType.principal,
        systemPromptSpecialization: 'Focus on at-risk cohorts.',
      );
      const context = CopilotScreenContext(
        personaRole: CopilotPersonaRole.principal,
        erpRole: ErpRole.principal,
        schoolId: 'school_001',
        organizationId: 'org_001',
        tenantId: 'tenant_001',
        module: 'management',
        route: RouteNames.managementDashboard,
        screen: 'Owner Dashboard',
      );

      final prompt = service.buildSystemPrompt(
        profile: profile,
        screenContext: context,
      );

      expect(prompt, contains('Principal'));
      expect(prompt, contains('Owner Dashboard'));
      expect(prompt, contains('management'));
      expect(prompt, contains('Focus on at-risk cohorts.'));
    });
  });
}
