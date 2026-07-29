import 'dart:typed_data';

import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/parent/fees/fee_certificate_models.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/parent_fee_certificate_pdf_service.dart';
import 'package:akshara_erp/features/parent/fees/payment_history_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

const _history = <PaymentHistoryItem>[
  PaymentHistoryItem(
    id: 'p1',
    title: 'Term 1 — Full payment',
    dateLabel: '15 Apr 2025',
    amount: 18000,
    statusLabel: 'Paid',
    isSuccess: true,
  ),
];

/// A mock parent repo that certifies an EMPTY (zero-payment) year, for the
/// honest-empty path.
class _EmptyCertParentRepository extends MockParentRepository {
  @override
  Future<FeeCertificateData> getFeeCertificate({
    required RepositoryQuery query,
    String? academicYear,
  }) async {
    return FeeCertificateData(
      schoolName: 'NIKSHA Public School',
      guardianName: 'Suresh Kumar',
      studentName: 'Ravi Kumar',
      academicYear: academicYear ?? '2025-2026',
      totalPaidAmount: 0,
      payments: const [],
      signatoryTitle: 'Principal',
    );
  }
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required List<Override> extra,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(extra),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const PaymentHistorySheet(items: _history),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('PAR-D3 · fee payment certificate (80C) action', () {
    testWidgets('renders the 80C action + opens the year picker',
        (tester) async {
      await _pumpSheet(tester, extra: const []);

      final action = find.byKey(QaTestKeys.parentFeeCertificateButton);
      expect(action, findsOneWidget);
      expect(find.text('Fee payment certificate (80C)'), findsOneWidget);

      await tester.tap(action);
      await tester.pumpAndSettle();

      // Year picker opens with the current FY option available.
      expect(
        find.byKey(QaTestKeys.parentFeeCertificateYearPicker),
        findsOneWidget,
      );
      final currentFy =
          PaymentHistorySheet.currentFinancialYearLabel(DateTime(2025, 6, 1));
      expect(
        find.byKey(QaTestKeys.parentFeeCertificateYearOption(currentFy)),
        findsOneWidget,
      );
    });

    testWidgets('honest empty message when nothing was paid for the year',
        (tester) async {
      await _pumpSheet(
        tester,
        extra: [
          parentRepositoryProvider.overrideWithValue(
            _EmptyCertParentRepository(),
          ),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.parentFeeCertificateButton));
      await tester.pumpAndSettle();

      // Pick the first offered year.
      final options = PaymentHistorySheet.financialYearOptions();
      await tester.tap(
        find.byKey(QaTestKeys.parentFeeCertificateYearOption(options.first)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.parentFeeCertificateEmptyMessage),
        findsOneWidget,
      );
      expect(
        find.text('No payments recorded for ${options.first}'),
        findsOneWidget,
      );
    });

    testWidgets('builds + shares the PDF when the year has payments',
        (tester) async {
      Uint8List? sharedBytes;
      final fakePdf = ParentFeeCertificatePdfService(
        sharePdf: ({required bytes, required filename}) async =>
            sharedBytes = bytes,
      );

      await _pumpSheet(
        tester,
        extra: [
          parentFeeCertificatePdfServiceProvider.overrideWithValue(fakePdf),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.parentFeeCertificateButton));
      await tester.pumpAndSettle();

      final options = PaymentHistorySheet.financialYearOptions();
      await tester.tap(
        find.byKey(QaTestKeys.parentFeeCertificateYearOption(options.first)),
      );
      await tester.pumpAndSettle();

      // The mock repo certifies a non-empty year, so the PDF is built + shared.
      expect(sharedBytes, isNotNull);
      expect(sharedBytes, isNotEmpty);
      expect(
        find.byKey(QaTestKeys.parentFeeCertificateEmptyMessage),
        findsNothing,
      );
    });
  });
}
