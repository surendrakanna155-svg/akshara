import 'package:akshara_erp/core/repositories/api/sis/mapper/sis_mapper.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_screen.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

SisStudent _student(
  String id,
  String name, {
  required String guardian,
  required String phone,
  String admission = '',
  String classLabel = '5',
  String section = 'A',
}) {
  return SisStudent(
    id: id,
    studentName: name,
    admissionNumber: admission,
    classLabel: classLabel,
    section: section,
    academicYear: '2026–27',
    status: SisStudentStatus.active,
    gender: 'Female',
    dateOfBirth: '01 Jan 2014',
    guardianName: guardian,
    phone: phone,
    email: 'parent@example.com',
    enrolledAt: 'Jan 2026',
  );
}

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

Future<void> _pumpProfile(WidgetTester tester, String studentId) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: SisStudentProfileScreen(studentId: studentId),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_resetSisStore);

  group('SIS-4 siblings — mock repository contract', () {
    test('returns shared-guardian siblings, self- and stranger-excluded',
        () async {
      MockSisWriteStore.instance.students = [
        _student('sib-a', 'Aarav Rao',
            guardian: 'Meera Rao', phone: '+91 90000 00001'),
        _student('sib-b', 'Bhavna Rao',
            guardian: 'Meera Rao', phone: '+91 90000 00001'),
        _student('sib-c', 'Chetan Singh',
            guardian: 'Other Parent', phone: '+91 90000 00009'),
      ];
      final repo = MockSisRepository();
      const query = RepositoryQuery.demo;

      final siblings =
          await repo.listStudentSiblings(query: query, studentId: 'sib-a');

      // Only the student sharing the guardian is returned.
      expect(siblings.map((s) => s.studentId).toList(), ['sib-b']);
      // Self is never listed as its own sibling.
      expect(siblings.any((s) => s.studentId == 'sib-a'), isFalse);
      // A student with a different guardian is excluded.
      expect(siblings.any((s) => s.studentId == 'sib-c'), isFalse);
    });

    test('returns empty when the student has no shared guardian', () async {
      MockSisWriteStore.instance.students = [
        _student('lonely', 'Lone Child',
            guardian: 'Solo Parent', phone: '+91 90000 00002'),
        _student('other', 'Other Child',
            guardian: 'Diff Parent', phone: '+91 90000 00003'),
      ];
      final repo = MockSisRepository();

      final siblings = await repo.listStudentSiblings(
        query: RepositoryQuery.demo,
        studentId: 'lonely',
      );

      expect(siblings, isEmpty);
    });
  });

  group('SIS-4 siblings — API mapper contract', () {
    test('maps the backend siblings API row shape (mock↔api aligned)', () {
      const mapper = SisMapper();
      // Exactly the camelCase keys the backend `studentSiblingItemToApi` emits.
      final sibling = mapper.toSibling(const {
        'studentId': 'stu-1',
        'studentCode': 'STU-1',
        'displayName': 'Bhavna Sibling',
        'status': 'active',
        'admissionNumber': 'ADM-1',
        'publicStudentId': 'DPSKKP-0002',
        'className': '5',
        'sectionName': 'A',
      });

      expect(sibling.studentId, 'stu-1');
      expect(sibling.studentName, 'Bhavna Sibling');
      expect(sibling.admissionNumber, 'ADM-1');
      expect(sibling.classLabel, '5');
      expect(sibling.section, 'A');
      expect(sibling.status, SisStudentStatus.active);
    });
  });

  group('SIS-4 siblings — profile section widget', () {
    testWidgets('renders linked siblings, self + stranger excluded',
        (tester) async {
      MockSisWriteStore.instance.students = [
        _student('sib-a', 'Aarav Rao',
            guardian: 'Meera Rao',
            phone: '+91 90000 00001',
            admission: 'ADM-A',
            classLabel: '5',
            section: 'A'),
        _student('sib-b', 'Bhavna Rao',
            guardian: 'Meera Rao',
            phone: '+91 90000 00001',
            admission: 'ADM-B',
            classLabel: '7',
            section: 'B'),
        _student('sib-c', 'Chetan Singh',
            guardian: 'Other Parent',
            phone: '+91 90000 00009',
            admission: 'ADM-C',
            classLabel: '9',
            section: 'C'),
      ];

      await _pumpProfile(tester, 'sib-a');

      // Section rendered.
      expect(find.byKey(QaTestKeys.sisSiblingsSection), findsOneWidget);
      // The shared-guardian sibling is shown as a tappable row.
      expect(find.byKey(QaTestKeys.sisSiblingRow('sib-b')), findsOneWidget);
      expect(find.text('Bhavna Rao'), findsOneWidget);
      // Self is not listed as its own sibling row.
      expect(find.byKey(QaTestKeys.sisSiblingRow('sib-a')), findsNothing);
      // The unrelated student never appears.
      expect(find.byKey(QaTestKeys.sisSiblingRow('sib-c')), findsNothing);
      expect(find.text('Chetan Singh'), findsNothing);
    });

    testWidgets('shows the empty state when there are no siblings',
        (tester) async {
      MockSisWriteStore.instance.students = [
        _student('lonely', 'Lone Child',
            guardian: 'Solo Parent', phone: '+91 90000 00002'),
      ];

      await _pumpProfile(tester, 'lonely');

      expect(find.byKey(QaTestKeys.sisSiblingsSection), findsOneWidget);
      expect(
        find.text('No siblings on record in this school.'),
        findsOneWidget,
      );
    });
  });
}
