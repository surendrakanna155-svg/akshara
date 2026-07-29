import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// BUS-013 — transport permission & role model.
///
/// The gaps this closes, all found by the Bus Tracking audit:
///
///   * There was NO driver role. `UserRole` was {parent, teacher, student,
///     staff} and `ErpRole` had no field roles, so a driver could not log in —
///     which means there was no GPS source, which means live tracking was
///     unreachable by construction. This is the root cause of the entire
///     tracking gap, not a missing feature.
///   * The parent role held no transport permission whatsoever, while the
///     parent screen called a school-scoped endpoint. Guaranteed 403 in the
///     live build.
///   * `ErpRole.student` held an EMPTY permission set, so no student-facing
///     surface was reachable at all.
///   * No attendant/conductor concept existed (grep returned zero).
///
/// Scopes are specified in docs/engineering/TRANSPORT_DOMAIN_CONTRACT.md §5.
/// These are CLIENT-side guards; the authoritative enforcement is RLS (BUS-028),
/// pinned separately.
void main() {
  Set<Permission> permsOf(ErpRole role) =>
      RolePermissionMatrix.permissionsFor(role).values;

  group('BUS-013 · driver role', () {
    test('exists and can operate its own trip', () {
      final perms = permsOf(ErpRole.driver);
      expect(perms, contains(Permission.viewOwnTransportTrip));
      expect(perms, contains(Permission.operateTransportTrip));
      expect(perms, contains(Permission.recordTransportBoarding));
      expect(perms, contains(Permission.raiseTransportSos));
    });

    test('cannot reach the ERP transport module or admin hub', () {
      final perms = permsOf(ErpRole.driver);
      expect(perms, isNot(contains(Permission.viewTransport)),
          reason: 'a driver must not read the school-wide transport module');
      expect(perms, isNot(contains(Permission.manageTransport)));
      expect(perms, isNot(contains(Permission.viewAdminHub)));
    });

    test('is not a staff ERP role — it logs into the driver app', () {
      expect(ErpRole.staffErpRoles, isNot(contains(ErpRole.driver)));
      expect(ErpRole.driver.isTransportFieldRole, isTrue);
    });
  });

  group('BUS-053 · attendant role', () {
    test('sees the trip and marks boarding but cannot control the trip', () {
      final perms = permsOf(ErpRole.attendant);
      expect(perms, contains(Permission.viewOwnTransportTrip));
      expect(perms, contains(Permission.recordTransportBoarding));
      expect(perms, contains(Permission.raiseTransportSos));
      expect(perms, isNot(contains(Permission.operateTransportTrip)),
          reason:
              'the person who marks boarding is not the person who starts the bus');
    });

    test('is a transport field role, not a staff ERP role', () {
      expect(ErpRole.staffErpRoles, isNot(contains(ErpRole.attendant)));
      expect(ErpRole.attendant.isTransportFieldRole, isTrue);
    });
  });

  group('BUS-013 · parent transport access', () {
    test('holds the own-child transport permission', () {
      expect(permsOf(ErpRole.parent), contains(Permission.viewChildTransport));
    });

    test('never holds the school-wide transport permissions', () {
      final perms = permsOf(ErpRole.parent);
      // The audit finding: a parent reaching viewTransport would have received
      // the school's whole allocation list — other children's names, admission
      // numbers, class, bus and PICKUP STOP.
      expect(perms, isNot(contains(Permission.viewTransport)));
      expect(perms, isNot(contains(Permission.manageTransport)));
      expect(perms, isNot(contains(Permission.viewOwnTransportTrip)),
          reason: 'trip-operator permissions are for field roles only');
      expect(perms, isNot(contains(Permission.recordTransportBoarding)));
    });
  });

  group('BUS-013 / BUS-101 · student transport access', () {
    test('no longer holds an empty permission set', () {
      expect(permsOf(ErpRole.student), isNotEmpty,
          reason:
              'the student role held {} so no student surface was reachable');
    });

    test('reads only its own transport, never a manifest', () {
      final perms = permsOf(ErpRole.student);
      expect(perms, contains(Permission.viewOwnTransport));
      expect(perms, isNot(contains(Permission.viewTransport)));
      expect(perms, isNot(contains(Permission.viewOwnTransportTrip)));
      expect(perms, isNot(contains(Permission.recordTransportBoarding)));
    });
  });

  group('BUS-013 · preserved separation of duties (P-10)', () {
    test('transportManager keeps exactly its admin-hub + transport grant', () {
      final perms = permsOf(ErpRole.transportManager);
      expect(perms, contains(Permission.viewTransport));
      expect(perms, contains(Permission.manageTransport));
      expect(perms, contains(Permission.viewAdminHub));
      // Must NOT acquire field-role permissions.
      expect(perms, isNot(contains(Permission.operateTransportTrip)));
    });

    test('principal stays read-only on transport', () {
      final perms = permsOf(ErpRole.principal);
      expect(perms, contains(Permission.viewTransport));
      expect(perms, isNot(contains(Permission.manageTransport)),
          reason: 'principal read-only on transport is a deliberate SoD split');
    });
  });

  group('BUS-013 · cross-role isolation', () {
    test('no non-field role may operate a trip', () {
      for (final role in ErpRole.values) {
        if (role.isTransportFieldRole) continue;
        expect(
          permsOf(role),
          isNot(contains(Permission.operateTransportTrip)),
          reason: '${role.name} must not be able to start/end a bus trip',
        );
      }
    });

    test('only the parent role may read a child\'s transport', () {
      for (final role in ErpRole.values) {
        if (role == ErpRole.parent) continue;
        expect(
          permsOf(role),
          isNot(contains(Permission.viewChildTransport)),
          reason: '${role.name} must not hold the parent child-scoped grant',
        );
      }
    });
  });
}
