import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:akshara_erp/router/parent_navigation.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  testWidgets('parent ai_copilot routes to persona assistant shell', (tester) async {
    final routes = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parentActiveStudentIdProvider.overrideWith((ref) => 'student_demo'),
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9000000002',
              displayName: 'QA Parent',
              role: UserRole.parent,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.parent),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => handleParentDashboardNavigation(
                      context,
                      'ai_copilot',
                      ref: ref,
                    ),
                    child: const Text('tap'),
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.aiAssistant,
                builder: (_, state) {
                  routes.add(state.uri.toString());
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap'));
    await tester.pumpAndSettle();

    expect(routes.any((r) => r.contains('/ai-assistant')), isTrue);
    expect(routes.any((r) => r.contains('/copilot')), isFalse);
  });
}
