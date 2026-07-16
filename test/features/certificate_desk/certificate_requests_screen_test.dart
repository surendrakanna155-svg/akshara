// PRC-A client — CertificateRequestsScreen: the raise FAB is gated on
// requestStudentCertificate, the queue renders honestly (including
// blocked_dues with its note), and Cancel is gated on approveCertificateRequest.

import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/certificate_desk/certificate_desk_datasource.dart';
import 'package:akshara_erp/features/certificate_desk/certificate_desk_models.dart';
import 'package:akshara_erp/features/certificate_desk/certificate_desk_providers.dart';
import 'package:akshara_erp/features/certificate_desk/certificate_requests_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A datasource returning a fixed list — no network.
class _FixedDataSource implements CertificateDeskDataSource {
  _FixedDataSource(this._items);
  final List<CertificateRequest> _items;

  @override
  Future<List<CertificateRequest>> list({String? status}) async => _items;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

CertificateRequest _request({String status = 'pending', String issueNote = ''}) =>
    CertificateRequest(
      id: 'cr-1',
      studentId: 'stu-1',
      certificateType: 'bonafide',
      purpose: 'scholarship',
      status: status,
      requestedBy: 'user-1',
      requestedByRole: 'staff',
      issueNote: issueNote,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<CertificateRequest> items,
  required Set<Permission> perms,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        certificateDeskDataSourceProvider.overrideWithValue(_FixedDataSource(items)),
        rbacServiceProvider.overrideWithValue(
          RbacService(
            UserPermissions(role: ErpRole.schoolAdmin, permissionSet: PermissionSet.from(perms)),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const CertificateRequestsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a maker with requestStudentCertificate sees the raise FAB', (tester) async {
    await _pump(tester, items: [_request()], perms: {Permission.requestStudentCertificate});
    expect(find.byKey(const Key('certificate-request-raise-button')), findsOneWidget);
  });

  testWidgets('a viewer WITHOUT requestStudentCertificate never sees the raise FAB', (tester) async {
    await _pump(tester, items: [_request()], perms: {});
    expect(find.byKey(const Key('certificate-request-raise-button')), findsNothing);
  });

  testWidgets('renders the queue with a status chip per request', (tester) async {
    await _pump(
      tester,
      items: [_request(status: 'blocked_dues', issueNote: '₹500 outstanding dues')],
      perms: {Permission.requestStudentCertificate},
    );
    expect(find.byKey(const Key('certificate-requests-list')), findsOneWidget);
    expect(find.byKey(const Key('certificate-request-tile-cr-1')), findsOneWidget);
  });

  testWidgets('an empty queue shows the empty state, not a spinner or error', (tester) async {
    await _pump(tester, items: const [], perms: {Permission.requestStudentCertificate});
    expect(find.text('No certificate requests yet.'), findsOneWidget);
  });

  testWidgets('opening a blocked_dues request shows the honest note, never a generic failure',
      (tester) async {
    await _pump(
      tester,
      items: [_request(status: 'blocked_dues', issueNote: '₹500 outstanding dues')],
      perms: {Permission.approveCertificateRequest},
    );
    await tester.tap(find.byKey(const Key('certificate-request-tile-cr-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('certificate-request-blocked-dues-note')), findsOneWidget);
    expect(find.textContaining('₹500 outstanding dues'), findsOneWidget);
  });

  testWidgets('Cancel is gated on approveCertificateRequest — a raiser without it cannot cancel',
      (tester) async {
    await _pump(
      tester,
      items: [_request(status: 'pending')],
      perms: {Permission.requestStudentCertificate},
    );
    await tester.tap(find.byKey(const Key('certificate-request-tile-cr-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('certificate-request-cancel-button')), findsNothing);
  });

  testWidgets('Cancel is offered to a holder of approveCertificateRequest on a pending request',
      (tester) async {
    await _pump(
      tester,
      items: [_request(status: 'pending')],
      perms: {Permission.approveCertificateRequest},
    );
    await tester.tap(find.byKey(const Key('certificate-request-tile-cr-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('certificate-request-cancel-button')), findsOneWidget);
  });

  testWidgets('an issued request is not cancellable regardless of permission', (tester) async {
    await _pump(
      tester,
      items: [_request(status: 'issued')],
      perms: {Permission.approveCertificateRequest},
    );
    await tester.tap(find.byKey(const Key('certificate-request-tile-cr-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('certificate-request-cancel-button')), findsNothing);
  });
}
