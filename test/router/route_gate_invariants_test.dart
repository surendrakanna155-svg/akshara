// Route-gate drift invariants (SEC — RC blocker, 2026-07-28).
//
// ROOT CAUSE this file exists to make impossible:
//   `RouteNames.adminErpRoutes` is the ONLY list both gates key off —
//   `isProtectedRoute` (the AUTH gate, app_router.dart) and
//   `canAccessErpRoute` (the RBAC gate, route_guards.dart, which begins
//   `if (!isAdminErpRoute(location)) return true;`). A route that declares a
//   permission in `kErpRouteViewPermissions` but is missing from
//   `adminErpRoutes` therefore gets NO auth gate and NO RBAC gate: it fails
//   OPEN. Nothing asserted the two lists agree, which is how `/student-health`,
//   `/certificate-requests`, `/gate-passes`, `/complaints` and
//   `/staff-360/:employeeId` shipped ungated.
//
// Verified to FAIL on the pre-fix tree: the drift assertion reported
//   [/certificate-requests, /complaints, /gate-passes, /parent/insights,
//    /staff-360, /student-health]
// and the two behavioural tests left a student on /student-health and an
// unauthenticated caller on /certificate-requests.
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/router/admin_navigation.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Routes that declare a view-permission but are deliberately NOT gated through
/// the admin ERP shell. Every entry MUST name the alternative gate that closes
/// it — an entry with no alternative gate is a security hole, not an exception.
///
/// Keep this set as small as humanly possible. Adding an entry is a security
/// decision and the reason belongs here, in writing.
const Map<String, String> kNonErpShellPermissionedRoutes = <String, String>{
  // ASIP Phase 1 "Report an issue to Akshara Support" is a shared,
  // persona-agnostic surface: EVERY authenticated school user may reach it.
  // Gated by `_isSharedSettingsRoute` (auth-only) in app_router.dart. The
  // `viewSupport` entry in kErpRouteViewPermissions documents the Phase-2
  // Akshara support-staff view contract; it intentionally gates nothing today.
  RouteNames.support: 'auth-only via _isSharedSettingsRoute (all personas)',
  // `/parent/insights` renders ParentInsightsScreen INSIDE the parent shell and
  // `viewParentInsights` is held by ErpRole.parent. It is closed by the
  // persona wall in `_canAccessRoute` (UserRole.parent owns `/parent/*`), not
  // by the ERP permission map. Residue, not a hole: staff roles that also hold
  // viewParentInsights cannot reach it — the screen would have to move into the
  // admin shell first. Out of scope for this security pass; tracked here so the
  // next person sees it rather than re-discovering it.
  RouteNames.parentInsights: 'parent-persona wall in _canAccessRoute',
};

AuthState get _studentAuth => const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Ravi Kumar',
      role: UserRole.student,
    );

AuthState get _teacherAuth => const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Priya Sharma',
      role: UserRole.teacher,
    );

void main() {
  group('route gate drift invariants', () {
    // ── THE invariant. Every declared permission must actually be evaluated. ──
    test(
        'every route with a declared view-permission is covered by the '
        'admin-ERP gating list', () {
      final ungated = kErpRouteViewPermissions.keys
          .where((route) => !isAdminErpRoute(route))
          .where((route) => !kNonErpShellPermissionedRoutes.containsKey(route))
          .toList()
        ..sort();

      expect(
        ungated,
        isEmpty,
        reason: 'These routes declare a Permission in kErpRouteViewPermissions '
            'but are NOT matched by isAdminErpRoute(), so canAccessErpRoute() '
            'returns true before ever consulting the permission map AND '
            'isProtectedRoute() never applies the auth gate. They fail OPEN. '
            'Add them to RouteNames.adminErpRoutes — or, if they genuinely are '
            'not admin-shell routes, document the alternative gate in '
            'kNonErpShellPermissionedRoutes: $ungated',
      );
    });

    // Converse direction: nothing may sit behind the ERP shell gate without a
    // declared permission, or the shell admits any authenticated staff user.
    test('every gated ERP route prefix resolves to a permission', () {
      final unpermissioned = RouteNames.adminErpRoutes
          .where((route) => erpRoutePermissionFor(route) == null)
          .toList()
        ..sort();

      expect(
        unpermissioned,
        isEmpty,
        reason: 'These prefixes are in RouteNames.adminErpRoutes but resolve to '
            'no Permission, so ErpRouteGuard admits ANY authenticated staff '
            'user regardless of role: $unpermissioned',
      );
    });

    // An "exception" that is not even auth-protected is a hole, not an
    // exception. Every documented exemption must still require a session.
    test('documented non-ERP permissioned routes are still auth-protected', () {
      for (final entry in kNonErpShellPermissionedRoutes.entries) {
        expect(
          isProtectedRoute(entry.key),
          isTrue,
          reason: '${entry.key} is exempted from the ERP shell gate '
              '("${entry.value}") but is not even auth-protected — an '
              'unauthenticated caller can reach it.',
        );
      }
    });

    // ── Auth gate coverage ────────────────────────────────────────────────
    test('every permissioned route is behind the authentication gate', () {
      final unprotected = kErpRouteViewPermissions.keys
          .where((route) => !isProtectedRoute(route))
          .toList()
        ..sort();

      expect(
        unprotected,
        isEmpty,
        reason: 'isProtectedRoute() returns false for these, so _authRedirect '
            'returns null for an UNAUTHENTICATED caller and they land inside '
            'the admin console: $unprotected',
      );
    });

    // ── P0-2 regression: the specific routes that shipped ungated ─────────
    test('PRC-A desks, Staff 360 and Sync Center are gated', () {
      const desks = <String>[
        RouteNames.certificateRequests,
        RouteNames.gatePasses,
        RouteNames.complaints,
        RouteNames.studentHealth,
        RouteNames.staff360,
      ];
      for (final route in desks) {
        expect(isAdminErpRoute(route), isTrue,
            reason: '$route must be inside the admin ERP shell gate');
        expect(erpRoutePermissionFor(route), isNotNull,
            reason: '$route must require a Permission');
        expect(isProtectedRoute(route), isTrue,
            reason: '$route must require authentication');
      }

      // Staff 360 is only ever routed with an :employeeId — the CONCRETE path
      // is what a deep-link supplies, so that is what must be gated.
      expect(isAdminErpRoute('${RouteNames.staff360}/HR-EMP-101'), isTrue);
      expect(
        erpRoutePermissionFor('${RouteNames.staff360}/HR-EMP-101'),
        isNotNull,
      );

      // Sync Center is app-wide — the SyncBanner in app.dart is rendered for
      // EVERY persona — so it must be auth-gated, not staff-gated. Putting it
      // behind the ERP shell would lock parents/teachers out of their own
      // offline queue.
      expect(isProtectedRoute(RouteNames.syncCenter), isTrue,
          reason: '/sync-center previously had no auth gate at all');
      expect(isAdminErpRoute(RouteNames.syncCenter), isFalse,
          reason: '/sync-center is reachable by every persona via SyncBanner');
    });

    // ── P0-1 regression: persona prefixes must match by path SEGMENT ──────
    //
    // `location.startsWith('/student')` also matches `/student-health` and
    // `/student-360`. Combined with the student arm of `_canAccessRoute`
    // (`UserRole.student => location.startsWith('/student')`) that handed a
    // logged-in student the whole-school Infirmary console. Persona ownership
    // is a path-segment fact, not a string-prefix fact.
    test('persona prefixes do not swallow same-prefix non-persona routes', () {
      const notPersonaOwned = <String>[
        RouteNames.studentHealth, // /student-health   — Infirmary console
        RouteNames.student360, // /student-360      — full student dossier
        RouteNames.staff360, // /staff-360        — employee dossier
        RouteNames.teacherAssistant, // /teacher-assistant
        RouteNames.parentMeetings, // /parent-meetings
      ];
      for (final route in notPersonaOwned) {
        for (final role in const [
          UserRole.student,
          UserRole.parent,
          UserRole.teacher,
        ]) {
          expect(
            isPersonaOwnedRoute(role, route),
            isFalse,
            reason: '$route is not a ${role.name}-owned route',
          );
        }
      }
    });

    test('persona prefixes still own their real routes', () {
      expect(
        isPersonaOwnedRoute(UserRole.student, RouteNames.studentDashboard),
        isTrue,
      );
      expect(
        isPersonaOwnedRoute(UserRole.parent, RouteNames.parentFees),
        isTrue,
      );
      expect(
        isPersonaOwnedRoute(UserRole.teacher, RouteNames.teacherHomeworkCreate),
        isTrue,
      );
      // Bare persona roots redirect into their shell and must stay owned.
      expect(isPersonaOwnedRoute(UserRole.parent, RouteNames.parent), isTrue);
      expect(isPersonaOwnedRoute(UserRole.teacher, RouteNames.teacher), isTrue);
      expect(isPersonaOwnedRoute(UserRole.student, RouteNames.student), isTrue);
      // Staff own no persona shell by prefix (their access is claim-based).
      expect(
        isPersonaOwnedRoute(UserRole.staff, RouteNames.teacherDashboard),
        isFalse,
      );
      expect(isPersonaOwnedRoute(null, RouteNames.parentFees), isFalse);
    });

    // ── Behavioural proof (real router, real redirects) ───────────────────
    testWidgets('a student cannot reach the school Infirmary console',
        (tester) async {
      final router = createAppRouter(readAuth: () => _studentAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _studentAuth,
      );
      router.go(RouteNames.studentHealth);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.studentDashboard,
        reason: 'a student must be bounced off /student-health, not handed the '
            "whole school's medical console",
      );
    });

    // P0-1(b): the module has to be USABLE by its intended users. Before the
    // fix, staff never reached their arm of `_canAccessRoute` (the
    // isAdminErpRoute branch was false), so a principal who tapped the
    // "Infirmary" tile — which IS rendered for permission-holders — was bounced
    // to /admin instantly. The permission must now be what decides, and it must
    // decide IN PLACE (Access Denied), not by redirect.
    testWidgets('Infirmary opens for a holder of viewStudentHealthRecord',
        (tester) async {
      // viewStudentHealthRecord is seeded SERVER-side (deliberately absent from
      // the client role matrix), so a real session carries it in its claims.
      final permitted = AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '9000000001',
        displayName: 'Principal',
        role: UserRole.staff,
        claims: AuthClaims.demoForRole(
          erpRole: ErpRole.principal,
          permissions: const [
            Permission.viewAdminHub,
            Permission.viewStudentHealthRecord,
          ],
        ),
      );
      final router = createAppRouter(readAuth: () => permitted);
      await pumpAksharaRouter(tester, router: router, authOverride: permitted);
      router.go(RouteNames.studentHealth);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.studentHealth,
        reason: 'a holder of viewStudentHealthRecord must reach the console — '
            'before the fix the tile bounced them straight to /admin',
      );
      expect(find.text('Access Denied'), findsNothing);
      expect(find.text('Infirmary'), findsAtLeastNWidgets(1));
    });

    testWidgets('Infirmary denies staff without viewStudentHealthRecord',
        (tester) async {
      // Denied IN PLACE by RBAC (AccessDeniedScreen), not by a silent redirect.
      final denied = AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '9000000002',
        displayName: 'Finance Admin',
        role: UserRole.staff,
        claims: AuthClaims.demoForRole(
          erpRole: ErpRole.financeAdmin,
          permissions: const [Permission.viewAdminHub, Permission.viewFinance],
        ),
      );
      final router = createAppRouter(readAuth: () => denied);
      await pumpAksharaRouter(tester, router: router, authOverride: denied);
      router.go(RouteNames.studentHealth);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.studentHealth,
      );
      expect(
        find.text('Access Denied'),
        findsOneWidget,
        reason: 'staff without viewStudentHealthRecord must be denied by RBAC',
      );
    });

    testWidgets('unauthenticated deep-links into the admin desks are bounced',
        (tester) async {
      for (final route in <String>[
        RouteNames.certificateRequests,
        RouteNames.gatePasses,
        RouteNames.complaints,
        RouteNames.studentHealth,
        '${RouteNames.staff360}/HR-EMP-101',
        RouteNames.syncCenter,
      ]) {
        final router = createAppRouter(
          readAuth: () => const AuthState(status: AuthStatus.unauthenticated),
        );
        await pumpAksharaRouter(tester, router: router);
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          RouteNames.login,
          reason: '$route must not be reachable without a session',
        );
      }
    });

    // ── P1-4 regression: teacher "More" tiles must actually open ──────────
    testWidgets('teacher More tiles reach real teacher-shell screens',
        (tester) async {
      final router = createAppRouter(readAuth: () => _teacherAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _teacherAuth,
      );
      for (final (route, heading) in const <(String, String)>[
        (RouteNames.teacherLessonLogs, 'Lesson Logs'),
        (RouteNames.teacherSyllabusProgress, 'Academic Progress'),
      ]) {
        router.go(route);
        await settleRiverpodFutures(tester);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          route,
          reason: '$route must open for a teacher, not bounce to the dashboard',
        );
        // A tile that opens a blank screen is no better than one that bounces.
        expect(
          find.text(heading),
          findsAtLeastNWidgets(1),
          reason: '$route must render its real screen inside TeacherShell',
        );
      }
    });

    testWidgets('the admin-shell originals stay closed to a teacher',
        (tester) async {
      // The teacher-shell siblings must NOT have widened the admin wall.
      final router = createAppRouter(readAuth: () => _teacherAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _teacherAuth,
      );
      for (final route in <String>[
        RouteNames.lessonLogs,
        RouteNames.academicProgress,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          RouteNames.teacherDashboard,
          reason: '$route is an admin-shell route and must stay staff-only',
        );
      }
    });

    // ── P2-8 regression: server-supplied deep links are validated ─────────
    testWidgets('push deep links are validated against the real route table',
        (tester) async {
      final router = createAppRouter(readAuth: () => _teacherAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _teacherAuth,
      );

      // Real, registered routes pass.
      expect(isKnownAppRoute(router, RouteNames.teacherDashboard), isTrue);
      expect(isKnownAppRoute(router, RouteNames.parentFees), isTrue);
      expect(
        isKnownAppRoute(router, '${RouteNames.staff360}/HR-EMP-101'),
        isTrue,
        reason: 'parameterised routes must still validate',
      );
      expect(
        isKnownAppRoute(router, '${RouteNames.teacherHomework}?filter=pending'),
        isTrue,
        reason: 'a query string must not invalidate a known route',
      );

      // Anything the route table cannot serve is dropped, not navigated to.
      for (final bad in <String>[
        '/definitely-not-a-route',
        '/teacher/../admin',
        'https://evil.example.com/phish',
        '//evil.example.com/phish',
        'teacher/dashboard', // no leading slash
        '',
      ]) {
        expect(
          isKnownAppRoute(router, bad),
          isFalse,
          reason: '"$bad" must be rejected before go() replaces the stack',
        );
      }
    });
  });
}
