import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_screen.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void _resetSisStore() {
  MockSisWriteStore.instance.students = null;
  MockSisWriteStore.instance.conversionQueue = null;
  MockSisWriteStore.instance.studentDocuments = null;
  MockSisWriteStore.instance.certificates.clear();
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_resetSisStore);

  group('Public Student ID surfacing (F1/F2)', () {
    testWidgets('profile header shows the public student ID', (tester) async {
      _useDesktopViewport(tester);
      await _pump(
        tester,
        const SisStudentProfileScreen(studentId: 'SIS-STU-10421'),
      );

      final psid = tester.widget<Text>(
        find.byKey(QaTestKeys.sisProfilePublicId),
      );
      expect(psid.data, 'Public ID: DPSKKP-0001');
    });

    testWidgets('registry desktop table shows a Public ID column + value',
        (tester) async {
      _useDesktopViewport(tester);
      await _pump(tester, const SisRegistryScreen());

      expect(find.text('Public ID'), findsOneWidget); // column header
      expect(find.text('DPSKKP-0001'), findsWidgets); // Arjun's PSID cell
    });

    testWidgets('registry mobile card shows the public ID under the row',
        (tester) async {
      useMobileViewport(tester);
      await _pump(tester, const SisRegistryScreen());

      expect(find.text('Public ID: DPSKKP-0001'), findsOneWidget);
    });
  });

  group('Admission number is set-once (read-only)', () {
    testWidgets('a student with an admission number shows a locked field',
        (tester) async {
      _useDesktopViewport(tester);
      await _pump(
        tester,
        const SisStudentProfileScreen(studentId: 'SIS-STU-10421'),
      );

      await tester.tap(find.byKey(QaTestKeys.sisEditProfileButton));
      await tester.pumpAndSettle();

      // The admission field is the read-only variant with the set-once helper.
      final field = tester.widget<TextField>(
        find.byKey(QaTestKeys.sisEditProfileAdmissionField),
      );
      expect(field.readOnly, isTrue);
      expect(field.enabled, isFalse);
      expect(find.text('Set once — cannot be changed.'), findsOneWidget);
    });
  });
}
