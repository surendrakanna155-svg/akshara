// QA-R-009 (Backup & DR) — Backup & Restore screen behaviour.
//
// The screen is a READ-ONLY backup-status view + school-owned exports. Database
// restore is OPERATOR-ASSISTED (runbook over SSH), NOT self-serve — there must be
// no in-app control that triggers a restore. These tests lock that contract.

import 'package:akshara_erp/features/admin/backup/backup_restore_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const BackupRestoreScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the read-only backup status panel', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Backup status'), findsOneWidget);
    expect(find.text('NIKSHA-managed database backups'), findsOneWidget);
    expect(find.textContaining('Nightly'), findsWidgets);
    // RPO note surfaced to the admin.
    expect(find.textContaining('≈ 24 hours'), findsOneWidget);
  });

  testWidgets('restore is presented as operator-assisted, not self-serve',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Restore'), findsOneWidget);
    expect(
      find.textContaining('operator-assisted'),
      findsWidgets,
    );
    expect(find.textContaining('BACKUP_RESTORE_RUNBOOK.md'), findsOneWidget);

    // No self-serve restore controls remain (the old fake dialog buttons).
    expect(find.text('Restore school'), findsNothing);
    expect(find.text('Validate snapshot'), findsNothing);
    expect(find.text('Validate manifest'), findsNothing);
  });

  testWidgets('school-owned export remains available', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Export package'), findsOneWidget);

    await tester.tap(find.text('Export package'));
    await tester.pumpAndSettle();
    // The export destination chooser opens (school-owned, unchanged behaviour).
    expect(find.text('Export destination'), findsOneWidget);
  });
}
