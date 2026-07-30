import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_validator.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_providers.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The manual-attendance approver queue had TWO client gates that disagreed with
/// each other and with the server:
///
///   * the button   — `canApproveManualAttendanceProvider`, on `manageHr`
///   * the route    — `ManagePermissionGuard(permission: manageHr)`
///   * the server   — the exact slug `approveStaffAttendance`
///
/// `manageHr` was wrong in BOTH directions. Principal and Vice-Principal, the
/// approvers the attendance design names, hold `approveStaffAttendance` but not
/// `manageHr` — so the feature was invisible to the people it was built for.
/// `hrManager` holds `manageHr` but not the approve slug — so they got a button
/// leading to a screen the server would refuse.
///
/// These tests pin the button and the route to the SAME slug the server
/// enforces, and pin the class trap that makes the naive fix silently worse.
RbacService _rbacFor(ErpRole role) =>
    RbacService(UserPermissions.forRole(role));

bool _buttonVisibleFor(ErpRole role) {
  final container = ProviderContainer(
    overrides: [rbacServiceProvider.overrideWithValue(_rbacFor(role))],
  );
  addTearDown(container.dispose);
  return container.read(canApproveManualAttendanceProvider);
}

void main() {
  const permission = Permission.approveStaffAttendance;

  group('manual-attendance approval gate', () {
    test('the named approvers can reach their own queue', () {
      // The regression. Both were locked out by the `manageHr` proxy.
      expect(_buttonVisibleFor(ErpRole.principal), isTrue);
      expect(_buttonVisibleFor(ErpRole.vicePrincipal), isTrue);
    });

    test('supervisory roles keep the access they already had', () {
      expect(_buttonVisibleFor(ErpRole.schoolAdmin), isTrue);
      expect(_buttonVisibleFor(ErpRole.management), isTrue);
      expect(_buttonVisibleFor(ErpRole.superAdmin), isTrue);
    });

    test('non-approvers never see it', () {
      expect(_buttonVisibleFor(ErpRole.teacher), isFalse);
      expect(_buttonVisibleFor(ErpRole.parent), isFalse);
      expect(_buttonVisibleFor(ErpRole.student), isFalse);
      // Any fail-closed sentinel role is covered by the whole-table assertions
      // below rather than named here, so this file stays independent of roles
      // being added to the enum.
    });

    test('an unauthenticated session approves nothing', () {
      final container = ProviderContainer(
        overrides: [
          rbacServiceProvider.overrideWithValue(const RbacService(null)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(canApproveManualAttendanceProvider), isFalse);
    });

    test(
        'the slug is approve-CLASS — a manage-guard holding it would deny '
        'everyone', () {
      // The trap the naive fix walks into. `hasManagePermission` requires the
      // permission NAME to start with `manage`, so
      // `ManagePermissionGuard(permission: approveStaffAttendance)` denies every
      // role unconditionally — worse than the bug it replaces. Renaming the
      // slug out of the `approve*` prefix would break the real guard the same
      // silent way, so pin the classification itself.
      expect(isApprovePermission(permission), isTrue);
      expect(isManagePermission(permission), isFalse);
      expect(
        _rbacFor(ErpRole.principal).hasManagePermission(permission),
        isFalse,
        reason: 'proves a manage-guard would lock out a genuine approver',
      );
      expect(
        _rbacFor(ErpRole.principal).hasApprovePermission(permission),
        isTrue,
      );
    });

    test('the button and the route guard agree for EVERY role', () {
      // The structural fix. A button that leads to a permission wall — or a
      // reachable screen with no way in — is only possible while these two
      // disagree, so compare them across the whole role table rather than
      // spot-checking personas.
      for (final role in ErpRole.values) {
        final button = _buttonVisibleFor(role);
        final route = _rbacFor(role).hasApprovePermission(permission);
        expect(
          button,
          route,
          reason: '${role.name}: button=$button but route=$route',
        );
      }
    });

    test('the gate tracks the role matrix, not a hand-listed set of personas',
        () {
      for (final role in ErpRole.values) {
        final granted =
            RolePermissionMatrix.permissionsFor(role).contains(permission);
        expect(
          _buttonVisibleFor(role),
          granted,
          reason: '${role.name} holds the slug but the gate disagrees',
        );
      }
    });
  });

  group('approver route guard', () {
    late SharedPreferences prefs;

    setUp(() async {
      // The DENY path audits the denial (`recordDeniedAccess`), which reads
      // SharedPreferences — so a refusal cannot even be rendered without it.
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> pumpGuardAs(WidgetTester tester, ErpRole role) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rbacServiceProvider.overrideWithValue(_rbacFor(role)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          // The real app theme: the refusal renders AksharaErrorState, which
          // reads the NIKSHA text extension, so a bare MaterialApp would fail
          // to build the very screen this test is about.
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ApprovePermissionGuard(
              permission: permission,
              auditRoute: '/hr/staff-attendance/requests',
              child: Scaffold(
                body: Text('approver queue', key: Key('approver-queue-body')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a Principal reaches the queue', (tester) async {
      await pumpGuardAs(tester, ErpRole.principal);
      expect(find.byKey(const Key('approver-queue-body')), findsOneWidget);
    });

    testWidgets('a Vice-Principal reaches the queue', (tester) async {
      await pumpGuardAs(tester, ErpRole.vicePrincipal);
      expect(find.byKey(const Key('approver-queue-body')), findsOneWidget);
    });

    testWidgets('a teacher is refused, not shown an empty queue',
        (tester) async {
      await pumpGuardAs(tester, ErpRole.teacher);
      expect(find.byKey(const Key('approver-queue-body')), findsNothing);
      expect(find.byType(AccessDeniedScreen), findsOneWidget);
    });
  });
}
