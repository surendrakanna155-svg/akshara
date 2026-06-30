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

/// QW8 · QA-R-008 — FULL-role RBAC allow/deny matrix (production security cert).
///
/// QW7 · QA-C-019 (`qa_c_019_rbac_behaviour_matrix_test.dart`) proved the
/// allow/deny UX over a representative slice — but only 7 of the role enum's
/// values (superAdmin, schoolAdmin, principal, financeAdmin, admissionsCounselor,
/// teacher, librarian). This cert closes the coverage gap by exercising the
/// REMAINING roles with representative allow + deny cases over the REAL role
/// matrix (`RbacService(UserPermissions.forRole)`), proving least-privilege:
///   allow → the route resolves accessible AND the guard renders the element;
///   deny  → the guard renders [AccessDeniedScreen] (element hidden) AND an
///           accessDenied audit event is written with route+permission metadata.
///
/// Between QA-C-019's 7 roles and this file's set, EVERY [ErpRole] value is
/// covered — guarded below by `coversAllRoles` so a future role added to the enum
/// cannot silently drop out of the security matrix.
///
/// Pattern mirrors QA-C-019 exactly: same `_Case`/`_ApproveCase` table shape,
/// same `ManagePermissionGuard`/`ApprovePermissionGuard` harness, same real
/// `AuditLogger` over mock prefs, same `manage ≠ approve` boundary assertions.
void main() {
  // ---- Roles QA-C-019 already exercises (do not re-test here) ---------------
  const qaC019Roles = <ErpRole>{
    ErpRole.superAdmin,
    ErpRole.schoolAdmin,
    ErpRole.principal,
    ErpRole.financeAdmin,
    ErpRole.admissionsCounselor,
    ErpRole.teacher,
    ErpRole.librarian,
  };

  // ---- Roles THIS file owns (the remainder of the enum) --------------------
  const qaR008Roles = <ErpRole>{
    ErpRole.vicePrincipal,
    ErpRole.management,
    ErpRole.parent,
    ErpRole.student,
    ErpRole.transportManager,
    ErpRole.hostelManager,
    ErpRole.inventoryManager,
    ErpRole.storekeeper,
  };

  // ---- Representative manage-permission grid (one allow + denies per role) --
  // (role, manage/view-permission, holder?, view-route, route-allowed-for-role?)
  const matrix = <_Case>[
    // Vice Principal — academic leadership: holds manageSis + manageManagement;
    // NOT the platform-only Control Center.
    _Case(ErpRole.vicePrincipal, Permission.manageSis, true,
        RouteNames.sis, true),
    _Case(ErpRole.vicePrincipal, Permission.manageManagement, true,
        RouteNames.management, true),
    _Case(ErpRole.vicePrincipal, Permission.manageControlCenter, false,
        RouteNames.controlCenter, false),

    // Management — exec layer: manageFinance + manageManagement + manageHr; but
    // NOT manageSis (record-keeping stays with admin/principal) and NOT the
    // platform Control Center.
    _Case(ErpRole.management, Permission.manageFinance, true,
        RouteNames.finance, true),
    _Case(ErpRole.management, Permission.manageSis, false,
        RouteNames.sis, true), // can VIEW SIS, cannot MANAGE it.
    _Case(ErpRole.management, Permission.manageControlCenter, false,
        RouteNames.controlCenter, false),

    // Parent — persona: its own experience surface; NO admin/finance/SIS at all.
    _Case(ErpRole.parent, Permission.viewParentExperience, true,
        RouteNames.parentExperience, true),
    _Case(ErpRole.parent, Permission.manageFinance, false,
        RouteNames.finance, false),
    _Case(ErpRole.parent, Permission.manageSis, false,
        RouteNames.sis, false),

    // Student — persona with the EMPTY grant set: every admin module is denied.
    _Case(ErpRole.student, Permission.manageFinance, false,
        RouteNames.finance, false),
    _Case(ErpRole.student, Permission.viewSis, false,
        RouteNames.sis, false),

    // Transport Manager — single-module staff: Transport yes; Finance + Library
    // (other staff modules) denied → proves horizontal least-privilege.
    _Case(ErpRole.transportManager, Permission.manageTransport, true,
        RouteNames.transport, true),
    _Case(ErpRole.transportManager, Permission.manageFinance, false,
        RouteNames.finance, false),
    _Case(ErpRole.transportManager, Permission.manageLibrary, false,
        RouteNames.library, false),

    // Hostel Manager — single-module staff: Hostel yes; Transport (sibling
    // module) denied.
    _Case(ErpRole.hostelManager, Permission.manageHostel, true,
        RouteNames.hostel, true),
    _Case(ErpRole.hostelManager, Permission.manageTransport, false,
        RouteNames.transport, false),

    // Inventory Manager — Inventory yes; Finance denied.
    _Case(ErpRole.inventoryManager, Permission.manageInventory, true,
        RouteNames.inventory, true),
    _Case(ErpRole.inventoryManager, Permission.manageFinance, false,
        RouteNames.finance, false),

    // Storekeeper — narrowest inventory hat: can VIEW inventory but NOT manage
    // it (manage stays with the Inventory Manager) → manage-deny on its own
    // module proves vertical least-privilege within a module.
    _Case(ErpRole.storekeeper, Permission.manageInventory, false,
        RouteNames.inventory, true), // view-route allowed (holds viewInventory)
    _Case(ErpRole.storekeeper, Permission.manageFinance, false,
        RouteNames.finance, false),
  ];

  // ---- Approve-permission slice (drives ApprovePermissionGuard) ------------
  const approveMatrix = <_ApproveCase>[
    // Vice Principal can approve education (academic authority) …
    _ApproveCase(ErpRole.vicePrincipal, Permission.approveEducation, true),
    // … but NOT finance refunds (finance authority is not delegated to it).
    _ApproveCase(ErpRole.vicePrincipal, Permission.approveRefunds, false),

    // Management approves fee concessions (exec finance authority) …
    _ApproveCase(ErpRole.management, Permission.approveFeeConcession, true),

    // Inventory Manager approves purchase orders (its own module) …
    _ApproveCase(ErpRole.inventoryManager, Permission.approvePurchaseOrder, true),
    // … but a transport manager CANNOT approve finance refunds — a transport
    // hat must never reach a finance approval (core anti-escalation boundary).
    _ApproveCase(ErpRole.transportManager, Permission.approveRefunds, false),
    // … and a parent/student persona holds NO approve authority anywhere.
    _ApproveCase(ErpRole.parent, Permission.approveRefunds, false),
    _ApproveCase(ErpRole.student, Permission.approveEducation, false),
    // Storekeeper can create POs but CANNOT approve them (manage ≠ approve, and
    // approve stays with the Inventory Manager).
    _ApproveCase(ErpRole.storekeeper, Permission.approvePurchaseOrder, false),
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

  group('QA-R-008 · enum coverage guard (no role escapes the security matrix)',
      () {
    test('QA-C-019 + QA-R-008 together cover EVERY ErpRole value', () {
      final coversAllRoles = <ErpRole>{...qaC019Roles, ...qaR008Roles};
      expect(coversAllRoles, equals(ErpRole.values.toSet()),
          reason: 'every ErpRole must be exercised by exactly one of the two '
              'RBAC matrices — a new enum value must be added to QA-R-008');
      // The two sets are disjoint (no double-owned role / accidental overlap).
      expect(qaC019Roles.intersection(qaR008Roles), isEmpty,
          reason: 'a role belongs to one matrix only');
    });

    test('every QA-R-008 case targets a role THIS file owns', () {
      final cased = <ErpRole>{
        ...matrix.map((c) => c.role),
        ...approveMatrix.map((c) => c.role),
      };
      expect(cased, equals(qaR008Roles),
          reason: 'the manage+approve grids must touch each owned role and no '
              'role outside this file\'s charter');
    });
  });

  group(
      'QA-R-008 · route-resolution layer (canAccessErpRoute over real roles)',
      () {
    for (final c in matrix) {
      test(
          '${c.role.name} ${c.routeAllowed ? "reaches" : "is denied"} '
          '${c.route} (perm ${c.permission.name})', () {
        final rbac = rbacFor(c.role);
        // Holder/non-holder of the (manage) permission matches the matrix. For a
        // view-permission case the manage check is vacuously false, so only
        // assert it for manage permissions.
        if (c.permission.name.startsWith('manage')) {
          expect(rbac.hasManagePermission(c.permission), c.isHolder,
              reason: '${c.role.name} manage(${c.permission.name})');
        } else {
          expect(rbac.hasPermission(c.permission), c.isHolder,
              reason: '${c.role.name} has(${c.permission.name})');
        }
        // The route guard's pure-RBAC decision matches the matrix.
        expect(canAccessErpRoute(rbac, c.route), c.routeAllowed,
            reason: '${c.role.name} canAccessErpRoute(${c.route})');
      });
    }
  });

  group(
      'QA-R-008 · ManagePermissionGuard UX (allow → child, deny → denied+audit)',
      () {
    for (final c in matrix) {
      // Only manage permissions drive ManagePermissionGuard (hasManagePermission
      // is false for non-manage slugs); view-only rows are covered above.
      if (!c.permission.name.startsWith('manage')) continue;
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

        final events = await audit.readByType(AuditEventType.accessDenied);
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
      'QA-R-008 · ApprovePermissionGuard UX (allow → child, deny → denied+audit)',
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
