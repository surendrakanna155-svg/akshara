import 'package:akshara_erp/core/repositories/api/auth/dto/auth_user_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/mapper/auth_mapper.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:akshara_erp/core/workspace/workspace.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:flutter_test/flutter_test.dart';

/// JOURNEY-002 / JOURNEY-003 — **the privilege-fallback guard.**
///
/// This file fails if the role fallback ever points *up* again.
///
/// ## What it would have caught
///
/// Before the fix:
///   * `auth_mapper.dart:63-66` → `ErpRole.fromName(...) ?? ErpRole.superAdmin`
///   * `auth_session_manager.dart:172` → the same `?? ErpRole.superAdmin`
///   * `auth_claims.dart:126-132` → `... ?? ErpRole.parent`
///
/// so an unrecognised server slug became the **highest privilege in the product**
/// on login and a parent on session restore. Every assertion below fails against
/// that code:
///   * `superAdmin` is not least privilege → the fallback test fails;
///   * login returns `superAdmin` and restore returns `parent` for the same slug
///     → the agreement test fails;
///   * the 29 server slugs resolve to something with permissions and a workspace
///     → the vocabulary test fails.
///
/// The permission/workspace assertions are the load-bearing half: "the fallback
/// is `unsupported`" is only worth anything if `unsupported` genuinely grants
/// nothing, so the outcome is asserted, not the enum name.
void main() {
  const mapper = AuthMapper();

  /// Resolution as the LOGIN path performs it (server user payload → AuthUser).
  ErpRole loginResolve(String? slug) {
    return mapper
        .toUser(AuthUserDto(raw: <String, dynamic>{
          'id': 'u1',
          'displayName': 'Test User',
          'tenantId': 't1',
          if (slug != null) 'role': slug,
        }))
        .erpRole;
  }

  /// Resolution as the SESSION-RESTORE path performs it (persisted JSON).
  ErpRole restoreResolve(String? slug) {
    return AuthClaims.fromJson(<String, dynamic>{
      'userId': 'u1',
      'tenantId': 't1',
      if (slug != null) 'role': slug,
    }).erpRole;
  }

  /// Resolution as the JWT-rehydration path performs it.
  ErpRole tokenResolve(String? slug) => ErpRole.resolve(slug);

  // Slugs that are not in the client enum, including the shapes an attacker or a
  // drifting server would actually produce.
  const unmappedSlugs = <String>[
    'organizationOwner',
    'organizationAdmin',
    'schoolGroupDirector',
    'financeManager',
    'marketingManager',
    'counselor',
    'petTeacher',
    'danceTeacher',
    'musicTeacher',
    'someTenantCustomRole',
    'SUPERADMIN',
    'super_admin',
    'unsupported',
    'unknown',
    '',
  ];

  group('JOURNEY-002 · an unresolvable role can never gain privilege', () {
    test('the sentinel holds NO permissions at all', () {
      final granted = RolePermissionMatrix.permissionsFor(ErpRole.unsupported);
      expect(
        granted.values,
        isEmpty,
        reason: 'ErpRole.unsupported must grant nothing — not even the blanket '
            'markStaffAttendance every other staff role inherits',
      );
      expect(
        RolePermissionMatrix.permissionsForRoles([ErpRole.unsupported]).values,
        isEmpty,
      );
    });

    test('the sentinel opens NO workspace', () {
      expect(kRoleWorkspaces[ErpRole.unsupported], isNull);
      expect(workspacesForRoles([ErpRole.unsupported]), isEmpty);
    });

    test(
        'every unmapped slug resolves to the sentinel on ALL THREE resolution '
        'paths — never to a privileged role', () {
      for (final slug in unmappedSlugs) {
        for (final entry in <String, ErpRole>{
          'login': loginResolve(slug),
          'restore': restoreResolve(slug),
          'token': tokenResolve(slug),
        }.entries) {
          expect(
            entry.value,
            ErpRole.unsupported,
            reason: '${entry.key} path resolved "$slug" to ${entry.value.name}',
          );
        }
      }
    });

    test('a null / absent role slug resolves to the sentinel, not superAdmin',
        () {
      expect(loginResolve(null), ErpRole.unsupported);
      expect(restoreResolve(null), ErpRole.unsupported);
      expect(tokenResolve(null), ErpRole.unsupported);
    });

    test(
        'no fallback anywhere yields a role holding MORE permissions than the '
        'least-privileged mapped role', () {
      // The real invariant, stated without naming the sentinel: whatever an
      // unmappable slug lands on must not out-grant the weakest real role.
      final weakest = ErpRole.supportedValues
          .map((r) => RolePermissionMatrix.permissionsFor(r).values.length)
          .reduce((a, b) => a < b ? a : b);
      for (final slug in unmappedSlugs) {
        for (final resolved in [
          loginResolve(slug),
          restoreResolve(slug),
          tokenResolve(slug),
        ]) {
          expect(
            RolePermissionMatrix.permissionsFor(resolved).values.length,
            lessThanOrEqualTo(weakest),
            reason: '"$slug" resolved to ${resolved.name}, which holds more '
                'permissions than the least-privileged mapped role',
          );
        }
      }
    });

    test('the sentinel is unreachable BY NAME from server data', () {
      // `fromName` iterates the enum, so a sentinel named `unknown` would let the
      // literal server slug "unknown" select it. It must stay unreachable.
      expect(ErpRole.fromName('unsupported'), isNull);
      expect(ErpRole.fromName('unknown'), isNull);
      expect(ErpRole.supportedValues, isNot(contains(ErpRole.unsupported)));
      expect(ErpRole.staffErpRoles, isNot(contains(ErpRole.unsupported)));
    });
  });

  group('JOURNEY-003 · login and session restore agree', () {
    test('every one of the 29 server slugs resolves identically on both paths',
        () {
      for (final slug in kServerRoleSlugs) {
        expect(
          loginResolve(slug),
          restoreResolve(slug),
          reason: 'server slug "$slug" resolves differently on login vs restore '
              '— the same user would change role between a fresh sign-in and an '
              'app relaunch',
        );
        expect(tokenResolve(slug), loginResolve(slug), reason: slug);
      }
    });

    test('a session round-trips through persistence without changing role', () {
      for (final slug in kServerRoleSlugs) {
        final resolved = ErpRole.resolve(slug);
        final claims = AuthClaims(
          userId: 'u1',
          erpRole: resolved,
          tenantId: 't1',
        );
        expect(
          AuthClaims.fromJson(claims.toJson()).erpRole,
          resolved,
          reason: '"$slug" changed identity across persist → restore',
        );
      }
    });
  });

  group('JOURNEY-002 · the 29-vs-client gap is closed and observable', () {
    test('every server slug is either MAPPED or explicitly triaged', () {
      final untriaged = <String>[];
      for (final slug in kServerRoleSlugs) {
        final mapped = ErpRole.fromName(slug) != null;
        final triaged = kDeliberatelyUnsupportedServerRoles.containsKey(slug);
        if (!mapped && !triaged) untriaged.add(slug);
      }
      expect(
        untriaged,
        isEmpty,
        reason: 'these server roles resolve to the fail-closed sentinel with no '
            'recorded reason — map them, or record why not in '
            'kDeliberatelyUnsupportedServerRoles: ${untriaged.join(', ')}',
      );
    });

    test('the triage list names only real, unmapped server roles', () {
      for (final slug in kDeliberatelyUnsupportedServerRoles.keys) {
        expect(kServerRoleSlugs, contains(slug),
            reason: '"$slug" is not a server role');
        expect(ErpRole.fromName(slug), isNull,
            reason: '"$slug" IS mapped — remove it from the unsupported list');
      }
      for (final reason in kDeliberatelyUnsupportedServerRoles.values) {
        expect(reason.length, greaterThan(20),
            reason: 'each exclusion must carry a real justification');
      }
    });

    test('the server vocabulary is the full 29 slugs', () {
      expect(kServerRoleSlugs.length, 29);
      expect(kServerRoleSlugs.toSet().length, 29, reason: 'no duplicates');
    });

    test('the five roles the server seeds are now MAPPED, not refused', () {
      // The enum additions must ship WITH the fail-closed default — shipping the
      // default alone locks these people out. This pins that they did.
      for (final slug in [
        'hrManager',
        'officeStaff',
        'healthStaff',
        'classTeacher',
        'coordinator',
      ]) {
        final role = ErpRole.fromName(slug);
        expect(role, isNotNull, reason: '$slug must be mapped');
        expect(role!.isSupported, isTrue);
        expect(kRoleWorkspaces[role], isNotNull,
            reason: '$slug must open a workspace');
        expect(RolePermissionMatrix.permissionsFor(role).values, isNotEmpty,
            reason: '$slug must hold its server-seeded permissions');
      }
    });

    test('the newly mapped roles do NOT hold platform-administration power', () {
      // Least privilege for the five: none of them may reach the platform
      // surfaces the old superAdmin fallback handed them.
      const forbidden = <Permission>[
        Permission.manageControlCenter,
        Permission.viewControlCenter,
        Permission.manageDirectorPortal,
        Permission.manageOnboarding,
      ];
      for (final role in [
        ErpRole.hrManager,
        ErpRole.officeStaff,
        ErpRole.healthStaff,
        ErpRole.classTeacher,
        ErpRole.coordinator,
      ]) {
        final granted = RolePermissionMatrix.permissionsFor(role);
        for (final p in forbidden) {
          expect(granted.contains(p), isFalse,
              reason: '${role.name} must not hold ${p.name}');
        }
      }
    });

    test('hrManager holds approveStaffAttendance, matching the server seed', () {
      // `20260820000000_staff_attendance_geofence_face_reimpl.sql:181-190` grants
      // approveStaffAttendance to {principal, vicePrincipal, schoolAdmin,
      // hrManager, management, superAdmin, organizationOwner, organizationAdmin}.
      // Every one of those this app maps must hold it, or an HR Manager loses the
      // manual-attendance approver queue the server would have let them use.
      for (final role in [
        ErpRole.principal,
        ErpRole.vicePrincipal,
        ErpRole.schoolAdmin,
        ErpRole.hrManager,
        ErpRole.management,
        ErpRole.superAdmin,
      ]) {
        expect(
          RolePermissionMatrix.permissionsFor(role)
              .contains(Permission.approveStaffAttendance),
          isTrue,
          reason: '${role.name} is in the server grant list for '
              'approveStaffAttendance but does not hold it client-side',
        );
      }
      // …and nobody outside that list does.
      for (final role in [
        ErpRole.teacher,
        ErpRole.classTeacher,
        ErpRole.officeStaff,
        ErpRole.healthStaff,
        ErpRole.coordinator,
        ErpRole.librarian,
        ErpRole.storekeeper,
        ErpRole.unsupported,
      ]) {
        expect(
          RolePermissionMatrix.permissionsFor(role)
              .contains(Permission.approveStaffAttendance),
          isFalse,
          reason: '${role.name} must not approve staff attendance',
        );
      }
    });
  });

  group('JOURNEY-002 · every mapped role is fully wired', () {
    test('no supported role is missing a permission set or a workspace', () {
      for (final role in ErpRole.supportedValues) {
        expect(kRoleWorkspaces[role], isNotNull,
            reason: '${role.name} opens no workspace — it would land nowhere');
        expect(kRoleWorkspaces[role], isNotEmpty, reason: role.name);
        for (final id in kRoleWorkspaces[role]!) {
          expect(kWorkspaceCatalog.containsKey(id), isTrue,
              reason: '${role.name} -> $id is not a catalogued workspace');
        }
      }
    });

    test('student is the only supported role with an empty permission set', () {
      final empty = ErpRole.supportedValues
          .where((r) => RolePermissionMatrix.permissionsFor(r).values.isEmpty)
          .toList();
      expect(empty, [ErpRole.student]);
    });
  });
}
