import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/audit/audit_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QW7 · QA-C-019 — RBAC behaviour matrix (role × permission).
///
/// Existing coverage proves the pieces in isolation:
///  • test/core/security/role_permissions_test.dart — the matrix has the right
///    grants per role.
///  • test/security/rbac/qw6_denied_access_audit_test.dart — a guarded deny
///    writes an accessDenied audit (uses synthetic Granting/empty RBAC).
///  • patrol_test/workflows/qw1_persona_rbac_isolation_e2e_test.dart — personas
///    reach their own module, denied others (live shell).
///
/// The genuine gap this cert closes: a single *behaviour* table that, for a
/// representative role × key-permission grid, asserts the FULL deny/allow UX in
/// one place over the REAL role matrix (RbacService(UserPermissions.forRole)):
///   allow  → the route resolves accessible AND the guard renders the element;
///   deny   → the guard renders [AccessDeniedScreen] (element hidden) AND an
///            accessDenied audit event is written with route+permission metadata.
/// It reuses the qw6 denied-audit harness (real AuditLogger over mock prefs) but
/// drives it from real roles instead of synthetic permission sets.
void main() {
  // ---- Representative grid -------------------------------------------------
  // (role, manage-permission, holder?, view-route, route-allowed-for-role?)
  const matrix = <_Case>[
    // Finance admin: holds manageFinance + viewFinance; no SIS, no Control Ctr.
    _Case(ErpRole.financeAdmin, Permission.manageFinance, true,
        RouteNames.finance, true),
    _Case(ErpRole.financeAdmin, Permission.manageSis, false,
        RouteNames.sis, false),
    _Case(ErpRole.financeAdmin, Permission.manageControlCenter, false,
        RouteNames.controlCenter, false),
    // School admin: SIS yes; Control Center no (platform-only).
    _Case(ErpRole.schoolAdmin, Permission.manageSis, true,
        RouteNames.sis, true),
    _Case(ErpRole.schoolAdmin, Permission.manageControlCenter, false,
        RouteNames.controlCenter, false),
    // Librarian (least-privilege staff): Library yes; Finance no.
    _Case(ErpRole.librarian, Permission.manageLibrary, true,
        RouteNames.library, true),
    _Case(ErpRole.librarian, Permission.manageFinance, false,
        RouteNames.finance, false),
    // Admissions counselor: Admissions yes; Finance no.
    _Case(ErpRole.admissionsCounselor, Permission.manageAdmissions, true,
        RouteNames.admissions, true),
    _Case(ErpRole.admissionsCounselor, Permission.manageFinance, false,
        RouteNames.finance, false),
    // Super admin: Control Center yes (only role that holds it).
    _Case(ErpRole.superAdmin, Permission.manageControlCenter, true,
        RouteNames.controlCenter, true),
    // Teacher: no admin manage perms over Finance/SIS, denied those routes.
    _Case(ErpRole.teacher, Permission.manageFinance, false,
        RouteNames.finance, false),
  ];

  // Approve-permission slice (drives ApprovePermissionGuard).
  const approveMatrix = <_ApproveCase>[
    _ApproveCase(ErpRole.financeAdmin, Permission.approveRefunds, true),
    _ApproveCase(ErpRole.librarian, Permission.approveRefunds, false),
    _ApproveCase(ErpRole.principal, Permission.approveEducation, true),
    _ApproveCase(ErpRole.teacher, Permission.approveEducation, false),
    // schoolAdmin can approve admissions; a counselor can MANAGE admissions but
    // NOT approve them (real least-privilege boundary — manage ≠ approve).
    _ApproveCase(ErpRole.schoolAdmin, Permission.approveAdmissions, true),
    _ApproveCase(ErpRole.admissionsCounselor, Permission.approveAdmissions, false),
  ];

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  RbacService rbacFor(ErpRole role) =>
      RbacService(UserPermissions.forRole(role));

  ProviderContainer containerFor(ErpRole role, AuditLogger audit) {
    final c = ProviderContainer(overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      rbacServiceProvider.overrideWithValue(rbacFor(role)),
      auditLoggerProvider.overrideWithValue(audit),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pumpGuard(
    WidgetTester tester,
    ProviderContainer container,
    Widget guard,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // Real Akshara theme so the production AccessDeniedScreen (which uses
        // AksharaErrorState → aksharaText) renders instead of throwing.
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: guard,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Guards fire recordDeniedAccess via unawaited(...) during build.
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('QA-C-019 · route-resolution layer (canAccessErpRoute over real roles)',
      () {
    for (final c in matrix) {
      test(
          '${c.role.name} ${c.routeAllowed ? "reaches" : "is denied"} '
          '${c.route} (perm ${c.permission.name})', () {
        final rbac = rbacFor(c.role);
        // Holder/non-holder of the manage permission matches the matrix.
        expect(rbac.hasManagePermission(c.permission), c.isHolder,
            reason: '${c.role.name} manage(${c.permission.name})');
        // The route guard's pure-RBAC decision matches the matrix.
        expect(canAccessErpRoute(rbac, c.route), c.routeAllowed,
            reason: '${c.role.name} canAccessErpRoute(${c.route})');
      });
    }
  });

  group('QA-C-019 · ManagePermissionGuard UX (allow → child, deny → denied+audit)',
      () {
    for (final c in matrix) {
      testWidgets(
          '${c.role.name} → ${c.permission.name}: '
          '${c.isHolder ? "renders element" : "AccessDenied + audit"}',
          (tester) async {
        final audit = AuditLogger(prefs);
        final container = containerFor(c.role, audit);

        await pumpGuard(
          tester,
          container,
          ManagePermissionGuard(
            permission: c.permission,
            auditRoute: c.route,
            child: const Text('protected-element'),
          ),
        );

        final events =
            await audit.readByType(AuditEventType.accessDenied);
        if (c.isHolder) {
          // ALLOW: element visible, no AccessDenied screen, no denial audit.
          expect(find.text('protected-element'), findsOneWidget);
          expect(find.byKey(QaTestKeys.accessDeniedScreen), findsNothing);
          expect(events, isEmpty,
              reason: 'a holder must not generate a denial audit');
        } else {
          // DENY: element hidden behind AccessDeniedScreen + audit recorded.
          expect(find.text('protected-element'), findsNothing,
              reason: 'protected element must be hidden from a non-holder');
          expect(find.byKey(QaTestKeys.accessDeniedScreen), findsOneWidget);
          expect(events, hasLength(1));
          expect(events.single.metadata['route'], c.route);
          expect(events.single.metadata['permission'], c.permission.name);
        }
      });
    }
  });

  group(
      'QA-C-019 · ApprovePermissionGuard UX (allow → child, deny → denied+audit)',
      () {
    for (final c in approveMatrix) {
      testWidgets(
          '${c.role.name} → ${c.permission.name}: '
          '${c.isHolder ? "renders element" : "AccessDenied + audit"}',
          (tester) async {
        final audit = AuditLogger(prefs);
        final container = containerFor(c.role, audit);
        const route = '/approvals';

        await pumpGuard(
          tester,
          container,
          ApprovePermissionGuard(
            permission: c.permission,
            auditRoute: route,
            child: const Text('approve-action'),
          ),
        );

        // Sanity: the real RBAC service agrees with the matrix.
        expect(rbacFor(c.role).hasApprovePermission(c.permission), c.isHolder);

        final events = await audit.readByType(AuditEventType.accessDenied);
        if (c.isHolder) {
          expect(find.text('approve-action'), findsOneWidget);
          expect(find.byKey(QaTestKeys.accessDeniedScreen), findsNothing);
          expect(events, isEmpty);
        } else {
          expect(find.text('approve-action'), findsNothing);
          expect(find.byKey(QaTestKeys.accessDeniedScreen), findsOneWidget);
          expect(events, hasLength(1));
          expect(events.single.metadata['permission'], c.permission.name);
        }
      });
    }
  });
}

class _Case {
  const _Case(
    this.role,
    this.permission,
    this.isHolder,
    this.route,
    this.routeAllowed,
  );

  final ErpRole role;
  final Permission permission;
  final bool isHolder;
  final String route;
  final bool routeAllowed;
}

class _ApproveCase {
  const _ApproveCase(this.role, this.permission, this.isHolder);
  final ErpRole role;
  final Permission permission;
  final bool isHolder;
}
