import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

const _studentId = 'SIS-STU-10421';
const _pendingDocId = 'SIS-DOC-903';

void _resetSisStore() {
  MockSisWriteStore.instance.students = null;
  MockSisWriteStore.instance.conversionQueue = null;
  MockSisWriteStore.instance.studentDocuments = null;
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpProfile(WidgetTester tester) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const SisStudentProfileScreen(studentId: _studentId),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_resetSisStore);

  group('SIS-3 document verify / reject', () {
    testWidgets('pending document shows status chip and decision actions',
        (tester) async {
      await _pumpProfile(tester);

      expect(find.text('Pending'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.sisDocumentVerifyButton(_pendingDocId)),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.sisDocumentRejectButton(_pendingDocId)),
        findsOneWidget,
      );
    });

    testWidgets('verify action calls the repo and flips status to verified',
        (tester) async {
      await _pumpProfile(tester);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.sisDocumentVerifyButton(_pendingDocId)),
      );
      await tester
          .tap(find.byKey(QaTestKeys.sisDocumentVerifyButton(_pendingDocId)));
      await tester.pumpAndSettle();

      expect(find.text('Verify document'), findsOneWidget);
      await tester.enterText(
        find.byKey(QaTestKeys.sisDocumentVerifyNoteField),
        'Original sighted',
      );
      await tester.tap(find.byKey(QaTestKeys.sisDocumentVerifySubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.sisDocumentVerifySuccessSnackbar),
        findsOneWidget,
      );

      // Repo effect: the mock store document flipped to verified + reviewer.
      final document = MockSisWriteStore.instance
          .documentsForStudent(_studentId)
          .firstWhere((doc) => doc.id == _pendingDocId);
      expect(document.status, 'verified');
      expect(document.verifiedBy, isNotNull);
      expect(document.verifiedAt, isNotNull);

      // UI effect: no pending document left, so no decision actions remain.
      expect(find.text('Pending'), findsNothing);
      expect(
        find.byKey(QaTestKeys.sisDocumentVerifyButton(_pendingDocId)),
        findsNothing,
      );
      expect(find.textContaining('Verified by'), findsOneWidget);
    });

    testWidgets('reject action flips status to rejected', (tester) async {
      await _pumpProfile(tester);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.sisDocumentRejectButton(_pendingDocId)),
      );
      await tester
          .tap(find.byKey(QaTestKeys.sisDocumentRejectButton(_pendingDocId)));
      await tester.pumpAndSettle();

      expect(find.text('Reject document'), findsOneWidget);
      await tester.enterText(
        find.byKey(QaTestKeys.sisDocumentVerifyNoteField),
        'Blurry scan',
      );
      await tester.tap(find.byKey(QaTestKeys.sisDocumentVerifySubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      final document = MockSisWriteStore.instance
          .documentsForStudent(_studentId)
          .firstWhere((doc) => doc.id == _pendingDocId);
      expect(document.status, 'rejected');

      expect(find.text('Rejected'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.sisDocumentRejectButton(_pendingDocId)),
        findsNothing,
      );
    });

    testWidgets('cancelling the dialog leaves the document pending',
        (tester) async {
      await _pumpProfile(tester);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.sisDocumentVerifyButton(_pendingDocId)),
      );
      await tester
          .tap(find.byKey(QaTestKeys.sisDocumentVerifyButton(_pendingDocId)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      final document = MockSisWriteStore.instance
          .documentsForStudent(_studentId)
          .firstWhere((doc) => doc.id == _pendingDocId);
      expect(document.status, 'pending');
      expect(find.text('Pending'), findsOneWidget);
    });
  });
}
