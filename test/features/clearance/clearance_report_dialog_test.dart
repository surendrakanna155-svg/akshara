// SCE-1 slice 4 — the clearance report dialog: honest verdict + not-tracked
// caveat, and the "Request dues waiver" affordance gated on manageSis + blocked.

import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/clearance/clearance_datasource.dart';
import 'package:akshara_erp/features/clearance/clearance_models.dart';
import 'package:akshara_erp/features/clearance/clearance_providers.dart';
import 'package:akshara_erp/features/clearance/widgets/clearance_report_dialog.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A datasource returning a fixed report — no network.
class _FixedDataSource implements ClearanceDataSource {
  _FixedDataSource(this._report);
  final ClearanceReport _report;
  @override
  Future<ClearanceReport> report({required String studentId, String lifecycle = 'transfer_certificate'}) async =>
      _report;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

ClearanceReport _report({required bool blocked, double amount = 0, List<String> notTracked = const []}) =>
    ClearanceReport(
      studentId: 'stu-1',
      lifecycle: 'transfer_certificate',
      blocked: blocked,
      blockingAmount: amount,
      totalOutstanding: amount,
      contributions: [
        ClearanceContribution(
          module: 'finance',
          status: blocked ? 'pending' : 'cleared',
          policy: 'blocking',
          amount: amount,
        ),
        for (final m in notTracked)
          ClearanceContribution(module: m, status: 'not_tracked', policy: 'advisory', amount: 0),
      ],
      notTracked: notTracked,
    );

Future<void> _pump(
  WidgetTester tester, {
  required ClearanceReport report,
  required Set<Permission> perms,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clearanceDataSourceProvider.overrideWithValue(_FixedDataSource(report)),
        rbacServiceProvider.overrideWithValue(
          RbacService(UserPermissions(role: ErpRole.schoolAdmin, permissionSet: PermissionSet.from(perms))),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(
          body: ClearanceReportDialog(studentId: 'stu-1', studentName: 'Asha'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blocked report shows the block verdict + not-tracked caveat', (tester) async {
    await _pump(
      tester,
      report: _report(blocked: true, amount: 500, notTracked: ['library', 'hostel']),
      perms: {Permission.manageSis},
    );
    expect(find.byKey(const Key('clearance-verdict')), findsOneWidget);
    expect(find.textContaining('Blocked'), findsOneWidget);
    expect(find.byKey(const Key('clearance-not-tracked-note')), findsOneWidget);
  });

  testWidgets('a blocked report shows "Request dues waiver" for a manageSis maker', (tester) async {
    await _pump(tester, report: _report(blocked: true, amount: 500), perms: {Permission.manageSis});
    expect(find.byKey(const Key('clearance-request-waiver-button')), findsOneWidget);
  });

  testWidgets('a CLEARED report never shows the waiver affordance', (tester) async {
    await _pump(tester, report: _report(blocked: false), perms: {Permission.manageSis});
    expect(find.byKey(const Key('clearance-request-waiver-button')), findsNothing);
    expect(find.textContaining('no blocking dues'), findsOneWidget);
  });

  testWidgets('a viewer WITHOUT manageSis cannot request a waiver even when blocked', (tester) async {
    await _pump(tester, report: _report(blocked: true, amount: 500), perms: {Permission.viewSis});
    expect(find.byKey(const Key('clearance-request-waiver-button')), findsNothing);
  });
}
