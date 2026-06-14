import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/dock/copilot_dock_provider.dart';
import 'package:akshara_erp/features/copilot/dock/copilot_floating_dock.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  group('copilotDockHiddenForRoute', () {
    test('hides on copilot and persona assistant routes', () {
      expect(copilotDockHiddenForRoute(RouteNames.copilot), isTrue);
      expect(copilotDockHiddenForRoute(RouteNames.aiAssistant), isTrue);
      expect(
        copilotDockHiddenForRoute('${RouteNames.copilot}/session/1'),
        isTrue,
      );
    });

    test('shows on ERP module routes', () {
      expect(
        copilotDockHiddenForRoute(RouteNames.managementDashboard),
        isFalse,
      );
      expect(copilotDockHiddenForRoute(RouteNames.teacherDashboard), isFalse);
    });
  });

  group('copilotDockIconForPersona', () {
    test('returns distinct icons per persona family', () {
      expect(
        copilotDockIconForPersona(CopilotPersonaRole.platformOwner),
        isNot(equals(copilotDockIconForPersona(CopilotPersonaRole.teacher))),
      );
      expect(
        copilotDockIconForPersona(CopilotPersonaRole.parent),
        isNot(equals(copilotDockIconForPersona(CopilotPersonaRole.student))),
      );
    });
  });

  group('copilotDockSemanticLabel', () {
    test('includes persona label and expanded state', () {
      expect(
        copilotDockSemanticLabel(
          CopilotPersonaRole.principal,
          expanded: false,
        ),
        contains('Principal'),
      );
      expect(
        copilotDockSemanticLabel(
          CopilotPersonaRole.principal,
          expanded: true,
        ),
        contains('expanded'),
      );
    });
  });

  group('CopilotFloatingDock widget', () {
    Future<void> pumpDock(
      WidgetTester tester, {
      required String route,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateOverride(erpWidgetTestStaffAuth()),
          ],
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: RouteNames.managementDashboard,
                  builder: (context, _) => const Scaffold(
                    body: SizedBox.expand(
                      child: Stack(
                        children: [CopilotFloatingDock()],
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: RouteNames.copilot,
                  builder: (_, __) => const SizedBox(),
                ),
              ],
              initialLocation: route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders collapsed FAB on ERP routes', (tester) async {
      await pumpDock(tester, route: RouteNames.managementDashboard);
      expect(find.byKey(QaTestKeys.copilotFloatingDockFab), findsOneWidget);
    });

    test('copilotDockExpandedProvider toggles expanded state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(copilotDockExpandedProvider), isFalse);
      container.read(copilotDockExpandedProvider.notifier).state = true;
      expect(container.read(copilotDockExpandedProvider), isTrue);
    });

    testWidgets('hides on copilot route', (tester) async {
      await pumpDock(tester, route: RouteNames.copilot);
      expect(find.byKey(QaTestKeys.copilotFloatingDockFab), findsNothing);
    });
  });
}
