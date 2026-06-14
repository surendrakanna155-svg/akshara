import 'package:akshara_erp/core/repositories/mock/mock_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/copilot_screen_context.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sendMessage embeds screenContext in context-aware stub reply', () async {
    final repo = MockCopilotRepository();
    const screenContext = CopilotScreenContext(
      personaRole: CopilotPersonaRole.platformOwner,
      erpRole: ErpRole.superAdmin,
      schoolId: 'school_001',
      organizationId: 'org_001',
      tenantId: 'tenant_001',
      module: 'management',
      route: RouteNames.managementDashboard,
      screen: 'Owner Dashboard',
      kpis: [
        CopilotKpiSnapshot(id: 'revenue_mtd', label: 'Revenue (MTD)', value: '₹1.2Cr'),
      ],
    );

    final result = await repo.sendMessage(
      query: RepositoryQuery.demo,
      sessionId: 'copilot_session_1',
      content: 'Compare school performance',
      screenContext: screenContext,
    );

    expect(result.stub, isTrue);
    expect(result.assistantMessage.content, contains('Platform Owner'));
    expect(result.assistantMessage.content, contains('Revenue (MTD)'));
    expect(result.userMessage.metadata['screenContext'], isNotNull);
  });
}
