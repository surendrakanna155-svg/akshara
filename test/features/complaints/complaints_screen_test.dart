// PRC-A Batch 2 — ComplaintsScreen: the queue, SLA breach visibility, and the
// raise action gated on `raiseComplaint`.

import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/complaints/complaints_datasource.dart';
import 'package:akshara_erp/features/complaints/complaints_models.dart';
import 'package:akshara_erp/features/complaints/complaints_providers.dart';
import 'package:akshara_erp/features/complaints/complaints_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedComplaintsDataSource implements ComplaintsDataSource {
  _FixedComplaintsDataSource(this._items);
  final List<Complaint> _items;

  @override
  Future<List<Complaint>> list({
    String? status,
    String? category,
    String? assignedTo,
    String? severity,
  }) async =>
      _items;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Complaint _complaint({
  String id = 'c1',
  String slaState = kSlaOnTrack,
  String status = 'open',
}) =>
    Complaint(
      id: id,
      category: 'facilities',
      title: 'Broken fan',
      description: 'Not spinning',
      severity: 'medium',
      status: status,
      raisedBy: 'user-1',
      raisedByRole: 'teacher',
      slaDueAt: '2026-07-16T10:00:00Z',
      slaState: slaState,
      reopenedCount: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<Complaint> items,
  required Set<Permission> perms,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        complaintsDataSourceProvider.overrideWithValue(_FixedComplaintsDataSource(items)),
        rbacServiceProvider.overrideWithValue(
          RbacService(UserPermissions(role: ErpRole.schoolAdmin, permissionSet: PermissionSet.from(perms))),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ComplaintsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the raise FAB for a raiseComplaint holder', (tester) async {
    await _pump(tester, items: [_complaint()], perms: {Permission.raiseComplaint});
    expect(find.byKey(const Key('complaints-raise-fab')), findsOneWidget);
  });

  testWidgets('hides the raise FAB for a viewer without raiseComplaint', (tester) async {
    await _pump(tester, items: [_complaint()], perms: {Permission.viewComplaintsPrincipal});
    expect(find.byKey(const Key('complaints-raise-fab')), findsNothing);
  });

  testWidgets('shows the SLA breach banner when a complaint has breached', (tester) async {
    await _pump(
      tester,
      items: [_complaint(id: 'c1', slaState: kSlaBreached)],
      perms: {Permission.manageComplaints},
    );
    expect(find.byKey(const Key('complaints-sla-breach-banner')), findsOneWidget);
    expect(find.textContaining('breached SLA'), findsOneWidget);
  });

  testWidgets('does NOT show the breach banner when everything is on track', (tester) async {
    await _pump(
      tester,
      items: [_complaint(id: 'c1', slaState: kSlaOnTrack)],
      perms: {Permission.manageComplaints},
    );
    expect(find.byKey(const Key('complaints-sla-breach-banner')), findsNothing);
  });

  testWidgets('shows an empty state when there are no complaints', (tester) async {
    await _pump(tester, items: const [], perms: {Permission.manageComplaints});
    expect(find.textContaining('No complaints match'), findsOneWidget);
  });

  testWidgets('tapping the raise FAB opens the raise dialog', (tester) async {
    await _pump(tester, items: const [], perms: {Permission.raiseComplaint});
    await tester.tap(find.byKey(const Key('complaints-raise-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complaints-raise-dialog')), findsOneWidget);
  });
}
