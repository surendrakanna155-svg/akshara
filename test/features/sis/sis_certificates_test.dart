import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/sis/certificates/sis_certificate_pdf_service.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_screen.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:akshara_erp/features/sis/sis_workflow_actions.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

const _query = RepositoryQuery.demo;
// Arjun (10421) has an open fee account → dues pending. Ananya Rao (10431) has
// none → the TC can be issued.
const _withDues = 'SIS-STU-10421';
const _noDues = 'SIS-STU-10431';

void _resetSisStore() {
  MockSisWriteStore.instance.students = null;
  MockSisWriteStore.instance.conversionQueue = null;
  MockSisWriteStore.instance.studentDocuments = null;
  MockSisWriteStore.instance.certificates.clear();
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1400);
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
  setUp(() {
    _resetSisStore();
    // Default renderer is a no-op so widget flows never touch the printing
    // platform channel (mirrors the HR/finance PDF test pattern).
    sisCertificatePdfRenderer = (_) async {};
  });

  tearDown(() {
    sisCertificatePdfRenderer = _defaultRendererSentinel;
  });

  group('SIS-1 mock certificate repository', () {
    late MockSisRepository repo;
    setUp(() => repo = MockSisRepository());

    test('issueCertificate records a bonafide issuance and returns data',
        () async {
      final data = await repo.issueCertificate(
        query: _query,
        studentId: _withDues,
        request: const IssueCertificateRequest(
          type: SisCertificateType.bonafide,
          reason: 'bank',
        ),
      );
      expect(data.type, SisCertificateType.bonafide);
      expect(data.serialNo, isNull);
      expect(data.studentName, 'Arjun Patel');
      expect(data.publicStudentId, 'DPSKKP-0001');
      expect(data.reason, 'bank');

      final register =
          await repo.listCertificates(query: _query, studentId: _withDues);
      expect(register, hasLength(1));
      expect(register.single.type, SisCertificateType.bonafide);
    });

    test('issueTransferCertificate blocks a student with outstanding dues',
        () async {
      expect(
        () => repo.issueTransferCertificate(
          query: _query,
          studentId: _withDues,
          request: const IssueTransferCertificateRequest(),
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('outstanding'),
          ),
        ),
      );
      // Nothing written: register stays empty and status unchanged.
      final register =
          await repo.listCertificates(query: _query, studentId: _withDues);
      expect(register, isEmpty);
    });

    test('issueTransferCertificate issues a serial and flips status', () async {
      final data = await repo.issueTransferCertificate(
        query: _query,
        studentId: _noDues,
        request: const IssueTransferCertificateRequest(reason: 'relocation'),
      );
      expect(data.type, SisCertificateType.transfer);
      expect(data.serialNo, isNotNull);
      expect(data.serialNo, contains('TC/'));

      final students = await repo.getStudents(query: _query);
      final student = students.items.firstWhere((s) => s.id == _noDues);
      expect(student.status, SisStudentStatus.transferred);

      final register =
          await repo.listCertificates(query: _query, studentId: _noDues);
      expect(register.single.type, SisCertificateType.transfer);
      expect(register.single.serialNo, isNotNull);
    });

    test('re-issuing a TC for an already-transferred student is rejected',
        () async {
      await repo.issueTransferCertificate(
        query: _query,
        studentId: _noDues,
        request: const IssueTransferCertificateRequest(),
      );
      expect(
        () => repo.issueTransferCertificate(
          query: _query,
          studentId: _noDues,
          request: const IssueTransferCertificateRequest(),
        ),
        throwsA(predicate((e) => e.toString().contains('already'))),
      );
    });
  });

  group('SIS-1 certificate UI', () {
    testWidgets('issue-certificate action renders a PDF and shows success',
        (tester) async {
      var rendered = 0;
      SisCertificateData? renderedData;
      sisCertificatePdfRenderer = (data) async {
        rendered++;
        renderedData = data;
      };

      await _pumpProfile(tester, _withDues);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.sisIssueCertificateButton),
      );
      await tester.tap(find.byKey(QaTestKeys.sisIssueCertificateButton));
      await tester.pumpAndSettle();

      // Dialog is open (type picker present).
      expect(
        find.byKey(QaTestKeys.sisIssueCertificateTypeField),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(QaTestKeys.sisIssueCertificateReasonField),
        'for scholarship',
      );
      await tester.tap(find.byKey(QaTestKeys.sisIssueCertificateSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.sisIssueCertificateSuccessSnackbar),
        findsOneWidget,
      );
      expect(rendered, 1);
      expect(renderedData?.type, SisCertificateType.bonafide);
      expect(renderedData?.reason, 'for scholarship');
    });

    testWidgets('transfer-certificate dues-pending surfaces a friendly error',
        (tester) async {
      var rendered = 0;
      sisCertificatePdfRenderer = (_) async => rendered++;

      await _pumpProfile(tester, _withDues);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.sisTransferCertificateButton),
      );
      await tester.tap(find.byKey(QaTestKeys.sisTransferCertificateButton));
      await tester.pumpAndSettle();

      expect(find.text('Issue transfer certificate'), findsOneWidget);
      await tester.tap(find.byKey(QaTestKeys.sisTransferCertificateSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Friendly error mentions clearing dues; no PDF was rendered.
      expect(find.textContaining('outstanding'), findsOneWidget);
      expect(rendered, 0);
      expect(
        find.byKey(QaTestKeys.sisTransferCertificateSuccessSnackbar),
        findsNothing,
      );
    });

    testWidgets('transfer-certificate success renders TC and reflects status',
        (tester) async {
      SisCertificateData? renderedData;
      sisCertificatePdfRenderer = (data) async => renderedData = data;

      await _pumpProfile(tester, _noDues);

      await tester.ensureVisible(
        find.byKey(QaTestKeys.sisTransferCertificateButton),
      );
      await tester.tap(find.byKey(QaTestKeys.sisTransferCertificateButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.sisTransferCertificateSubmitButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.sisTransferCertificateSuccessSnackbar),
        findsOneWidget,
      );
      expect(renderedData?.type, SisCertificateType.transfer);
      expect(renderedData?.serialNo, isNotNull);

      // Repo effect: the mock student flipped to transferred.
      final student = MockSisWriteStore.instance.students!
          .firstWhere((s) => s.id == _noDues);
      expect(student.status, SisStudentStatus.transferred);
    });

    testWidgets('certificate register lists issued certificates',
        (tester) async {
      // Seed a certificate directly so the register has a row to render.
      MockSisWriteStore.instance.students = null;
      final repo = MockSisRepository();
      await repo.issueCertificate(
        query: _query,
        studentId: _withDues,
        request: const IssueCertificateRequest(
          type: SisCertificateType.conduct,
        ),
      );

      await _pumpProfile(tester, _withDues);

      expect(find.byKey(QaTestKeys.sisCertificateRegister), findsOneWidget);
      expect(find.text('Certificates'), findsOneWidget);
      expect(find.textContaining('Conduct Certificate'), findsOneWidget);
    });
  });
}

// Restores the production renderer after each test.
Future<void> _defaultRendererSentinel(SisCertificateData data) async {
  const service = SisCertificatePdfService();
  final bytes = await service.buildCertificatePdf(data: data);
  await service.printCertificate(bytes);
}
