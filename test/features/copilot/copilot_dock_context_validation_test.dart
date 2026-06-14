import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/copilot/copilot_context_provider.dart';
import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/copilot_screen_context.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  group('buildCopilotScreenContext (INTEL-04 validation)', () {
    testWidgets('captures role, school, module, and screen from origin route', (
      tester,
    ) async {
      CopilotScreenContext? ctx;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateOverride(
              AuthState(
                status: AuthStatus.authenticated,
                phoneNumber: '9999999999',
                displayName: 'Director',
                role: UserRole.staff,
                claims: AuthClaims.demoForRole(erpRole: ErpRole.management),
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ctx = buildCopilotScreenContext(
                  ref,
                  originRoute: RouteNames.managementDashboard,
                  filters: const {'period': 'Q1'},
                  kpis: const [
                    CopilotKpiSnapshot(
                      id: 'revenue_mtd',
                      label: 'Revenue (MTD)',
                      value: '₹1.2Cr',
                    ),
                  ],
                  records: const {'approvalQueue': '7'},
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(ctx!.personaRole, CopilotPersonaRole.directorCorrespondent);
      expect(ctx!.erpRole, ErpRole.management);
      expect(ctx!.schoolId, isNotEmpty);
      expect(ctx!.tenantId, isNotEmpty);
      expect(ctx!.module, 'management');
      expect(ctx!.screen, 'Owner Dashboard');
      expect(ctx!.route, RouteNames.managementDashboard);
      expect(ctx!.filters['period'], 'Q1');
      expect(ctx!.kpis.first.label, 'Revenue (MTD)');
      expect(ctx!.records['approvalQueue'], '7');
    });

    test('pending navigation context overrides effective provider', () {
      const pending = CopilotScreenContext(
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
            id: 'revenue_mtd',
            label: 'Revenue (MTD)',
            value: '₹1.2Cr',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [authStateOverride(erpWidgetTestStaffAuth())],
      );
      addTearDown(container.dispose);

      container.read(copilotPendingNavigationContextProvider.notifier).state =
          pending;

      expect(container.read(copilotEffectiveContextProvider), pending);
      expect(
        container.read(copilotEffectiveContextProvider)!.displaySummary,
        contains('Owner Dashboard'),
      );
    });

    test('screen override is used when no pending navigation context', () {
      const override = CopilotScreenContext(
        personaRole: CopilotPersonaRole.principal,
        erpRole: ErpRole.principal,
        schoolId: 'school_001',
        organizationId: 'org_001',
        tenantId: 'tenant_001',
        module: 'sis',
        route: RouteNames.studentSuccessIntelligence,
        screen: 'Student Success',
        filters: {'grade': '10'},
        kpis: [
          CopilotKpiSnapshot(id: 'at_risk', label: 'At-risk', value: '12'),
        ],
      );

      final container = ProviderContainer(
        overrides: [authStateOverride(erpWidgetTestStaffAuth())],
      );
      addTearDown(container.dispose);

      container.read(copilotScreenOverrideProvider.notifier).state = override;

      expect(container.read(copilotEffectiveContextProvider), override);
      expect(
        container.read(copilotEffectiveContextProvider)!.kpis.first.value,
        '12',
      );
    });
  });
}
