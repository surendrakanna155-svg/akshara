import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/audit/audit_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QW6 · QA-X-017 (client leg) — a guarded deny RECORDS a denied-access audit.
///
/// `denied_mutation_test` proved the deny blocks the action; this proves the
/// matching security-observability event is actually persisted: when
/// [ManagePermissionGuard] / [ApprovePermissionGuard] block a route, the
/// `accessDenied` audit event is written with the route + permission metadata.
/// (The backend counterpart is `qw6_access_denied_audit_test.ts`.)
void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        // No permissions → every manage/approve check denies.
        rbacServiceProvider.overrideWithValue(const RbacService(null)),
        // Deterministic logger: persist to mock prefs, no upload queue.
        auditLoggerProvider.overrideWithValue(AuditLogger(prefs)),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpGuard(WidgetTester tester, Widget guard) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: guard)),
      ),
    );
    await tester.pumpAndSettle();
    // The guard fires recordDeniedAccess via unawaited(...) during build.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('ManagePermissionGuard deny records an accessDenied audit event',
      (tester) async {
    await pumpGuard(
      tester,
      const ManagePermissionGuard(
        permission: Permission.manageFinance,
        auditRoute: '/finance/collections',
        fallback: Text('denied'),
        child: Text('finance secret'),
      ),
    );

    expect(find.text('denied'), findsOneWidget);
    expect(find.text('finance secret'), findsNothing,
        reason: 'the guarded child must not render for a denied user');

    final events =
        await container.read(auditLoggerProvider).readByType(AuditEventType.accessDenied);
    expect(events, hasLength(1));
    expect(events.single.metadata['route'], '/finance/collections');
    expect(events.single.metadata['permission'], Permission.manageFinance.name);
  });

  testWidgets('ApprovePermissionGuard deny records an accessDenied audit event',
      (tester) async {
    await pumpGuard(
      tester,
      const ApprovePermissionGuard(
        permission: Permission.approveAdmissions,
        auditRoute: '/admissions/approvals',
        fallback: Text('denied'),
        child: Text('approve secret'),
      ),
    );

    expect(find.text('approve secret'), findsNothing);
    final events =
        await container.read(auditLoggerProvider).readByType(AuditEventType.accessDenied);
    expect(events, hasLength(1));
    expect(events.single.metadata['permission'], Permission.approveAdmissions.name);
  });

  testWidgets('a granted user renders the child and records NO denial',
      (tester) async {
    // Re-scope this test's container to a user that holds manageFinance.
    container.dispose();
    container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        rbacServiceProvider.overrideWithValue(
          const _GrantingRbac(<Permission>{Permission.manageFinance}),
        ),
        auditLoggerProvider.overrideWithValue(AuditLogger(prefs)),
      ],
    );

    await pumpGuard(
      tester,
      const ManagePermissionGuard(
        permission: Permission.manageFinance,
        auditRoute: '/finance/collections',
        fallback: Text('denied'),
        child: Text('finance secret'),
      ),
    );

    expect(find.text('finance secret'), findsOneWidget);
    final events =
        await container.read(auditLoggerProvider).readByType(AuditEventType.accessDenied);
    expect(events, isEmpty);
  });
}

/// A minimal [RbacService] that grants exactly the supplied manage permissions.
class _GrantingRbac implements RbacService {
  const _GrantingRbac(this._granted);
  final Set<Permission> _granted;

  @override
  bool hasManagePermission(Permission permission) => _granted.contains(permission);

  @override
  bool hasApprovePermission(Permission permission) => _granted.contains(permission);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
