import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:akshara_erp/features/management/approval/widgets/principal_digest_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// PRI-4 — the weekly principal digest card ("This week at a glance"). The
// feature shipped in the leadership wave; these close the verified test-coverage
// gap on its two behaviours: it renders for a management viewer when the digest
// has items, and hides entirely without viewManagement or when the digest is
// empty. Read-only card (no cron; XCT-2/deployment owns any scheduled send).

const _digest = PrincipalDigest(items: [
  PrincipalDigestItem(label: 'Approvals pending', value: '3', tone: 'warning'),
  PrincipalDigestItem(label: 'Waiting > 48h', value: '1', tone: 'error'),
]);

Future<void> _pump(
  WidgetTester tester, {
  required ErpRole role,
  required PrincipalDigest digest,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userPermissionsProvider
            .overrideWithValue(UserPermissions.forRole(role)),
        principalDigestProvider.overrideWithValue(digest),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: PrincipalDigestCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PRI-4 PrincipalDigestCard', () {
    testWidgets('renders the weekly digest for a management viewer',
        (tester) async {
      await _pump(tester, role: ErpRole.superAdmin, digest: _digest);

      expect(find.byKey(QaTestKeys.principalDigestCard), findsOneWidget);
      expect(find.text('This week at a glance'), findsOneWidget);
    });

    testWidgets('stays hidden for a role without viewManagement',
        (tester) async {
      await _pump(tester, role: ErpRole.parent, digest: _digest);

      expect(find.byKey(QaTestKeys.principalDigestCard), findsNothing);
    });

    testWidgets('stays hidden when the digest is empty', (tester) async {
      await _pump(
        tester,
        role: ErpRole.superAdmin,
        digest: const PrincipalDigest(items: []),
      );

      expect(find.byKey(QaTestKeys.principalDigestCard), findsNothing);
    });
  });
}
