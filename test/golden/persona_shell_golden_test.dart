@TestOn('mac-os')
library;

import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/admin/admin_shell.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/parent/shell/parent_shell.dart';
import 'package:akshara_erp/features/student_app/shell/student_shell.dart';
import 'package:akshara_erp/features/teacher/shell/teacher_shell.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/auth_test_overrides.dart';
import 'golden_test_helpers.dart';

/// P2-UX-3 — persona-shell goldens. Pins each persona's navigation shell chrome
/// (the stitch-persona theme + persona bottom-nav / rail) so a nav regression is
/// caught deliberately. QA-login is off ⇒ the QaPersonaSwitcherBar hides itself,
/// keeping the chrome deterministic.

class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Content'));
  }
}

typedef _ShellBuilder = Widget Function(Widget child);

Future<void> _pumpPersonaShell(
  WidgetTester tester, {
  required _ShellBuilder shell,
  required String initialLocation,
  required ErpRole erpRole,
  required UserRole userRole,
  required Size viewport,
}) async {
  suppressGoldenOverflowErrors();
  useGoldenViewport(tester, viewport);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => shell(child),
        routes: [
          GoRoute(
            path: initialLocation,
            builder: (_, __) => const _PlaceholderContent(),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateOverride(
          AuthState(
            status: AuthStatus.authenticated,
            phoneNumber: '9876543210',
            displayName: 'Persona',
            role: userRole,
            claims: AuthClaims.demoForRole(erpRole: erpRole),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  const viewport = GoldenViewports.mobile390;

  final personas = <({
    String name,
    _ShellBuilder shell,
    String route,
    ErpRole erp,
    UserRole user,
  })>[
    (
      name: 'admin',
      shell: (child) => AdminShell(child: child),
      route: RouteNames.admin,
      erp: ErpRole.superAdmin,
      user: UserRole.staff,
    ),
    (
      name: 'teacher',
      shell: (child) => TeacherShell(child: child),
      route: RouteNames.teacherDashboard,
      erp: ErpRole.teacher,
      user: UserRole.staff,
    ),
    (
      name: 'parent',
      shell: (child) => ParentShell(child: child),
      route: RouteNames.parentDashboard,
      erp: ErpRole.parent,
      user: UserRole.parent,
    ),
    (
      name: 'student',
      shell: (child) => StudentShell(child: child),
      route: RouteNames.studentDashboard,
      erp: ErpRole.student,
      user: UserRole.student,
    ),
  ];

  group('P2-UX-3 · persona-shell goldens', () {
    for (final persona in personas) {
      testWidgets('${persona.name} shell chrome', (tester) async {
        await _pumpPersonaShell(
          tester,
          shell: persona.shell,
          initialLocation: persona.route,
          erpRole: persona.erp,
          userRole: persona.user,
          viewport: viewport,
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            goldenFileName('persona_shell_${persona.name}', '390x844'),
          ),
        );
      });
    }
  });
}
