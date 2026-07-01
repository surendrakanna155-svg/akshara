import 'package:akshara_erp/core/repositories/api/finance/dto/finance_enum_codec.dart';
import 'package:akshara_erp/core/repositories/api/finance/finance_installment_plan_catalog.dart';
import 'package:akshara_erp/core/repositories/api/finance/hybrid_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/interfaces/finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/api/finance/api_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:dio/dio.dart';

void main() {
  group('Finance client alignment', () {
    test('refund approve path targets POST /finance/refunds/:id/approve', () {
      expect(
        FinanceApiPaths.refundApprove('refund-1'),
        '/finance/refunds/refund-1/approve',
      );
    });

    test('refund reject path targets POST /finance/refunds/:id/reject', () {
      expect(
        FinanceApiPaths.refundReject('refund-1'),
        '/finance/refunds/refund-1/reject',
      );
    });

    test('refund detail path targets GET /finance/refunds/:id', () {
      expect(
        FinanceApiPaths.refund('refund-1'),
        '/finance/refunds/refund-1',
      );
    });

    test('fee assignments list path uses deployed plural route', () {
      expect(FinanceApiPaths.feeAssignments, '/finance/fee-assignments');
    });

    test('assign fee plan path unchanged', () {
      expect(
        FinanceApiPaths.feeAssignmentAssign,
        '/finance/fee-assignment/assign',
      );
    });

    test('receipt path uses deployed route', () {
      expect(FinanceApiPaths.receipt('rcpt-1'), '/finance/receipts/rcpt-1');
    });

    test('dashboard path uses deployed route', () {
      expect(FinanceApiPaths.dashboard, '/finance/dashboard');
    });

    test('invoice paths match deployed routes', () {
      expect(FinanceApiPaths.invoices, '/finance/invoices');
      expect(FinanceApiPaths.invoice('inv-1'), '/finance/invoices/inv-1');
      expect(
        FinanceApiPaths.invoiceIssue('inv-1'),
        '/finance/invoices/inv-1/issue',
      );
      expect(
        FinanceApiPaths.invoiceCancel('inv-1'),
        '/finance/invoices/inv-1/cancel',
      );
    });

    // FIN-6 / FIN-9 — new additive routes.
    test('invoice installments path matches deployed route', () {
      expect(
        FinanceApiPaths.invoiceInstallments('inv-1'),
        '/finance/invoices/inv-1/installments',
      );
    });

    test('head-wise dues analytics path matches deployed route', () {
      expect(
        FinanceApiPaths.analyticsHeadWiseDues,
        '/finance/analytics/head-wise-dues',
      );
    });

    test('collection paths match deployed routes', () {
      expect(FinanceApiPaths.collections, '/finance/collections');
      expect(
        FinanceApiPaths.collectionDetail('col-1'),
        '/finance/collections/col-1',
      );
      expect(
        FinanceApiPaths.collectionCancel('col-1'),
        '/finance/collections/col-1/cancel',
      );
    });

    test('recovery paths match deployed routes', () {
      expect(FinanceApiPaths.recoveryContacts, '/finance/recovery/contacts');
      expect(
        FinanceApiPaths.recoveryContactsForStudent('stu-1'),
        '/finance/recovery/contacts/stu-1',
      );
      expect(FinanceApiPaths.recoveryPromises, '/finance/recovery/promises');
      expect(
        FinanceApiPaths.recoveryPromiseResolve('ptp-1'),
        '/finance/recovery/promises/ptp-1/resolve',
      );
      expect(FinanceApiPaths.recoveryDashboard, '/finance/recovery/dashboard');
    });

    test('recovery enum codecs round-trip backend wire values', () {
      expect(
        FinanceEnumCodec.recoveryChannelToApi(RecoveryChannel.whatsapp),
        'whatsapp',
      );
      expect(
        FinanceEnumCodec.recoveryOutcomeToApi(RecoveryOutcome.noAnswer),
        'no_answer',
      );
      expect(
        FinanceEnumCodec.parseRecoveryOutcome('partial_paid'),
        RecoveryOutcome.partialPaid,
      );
      expect(
        FinanceEnumCodec.promiseToPayStatusToApi(PromiseToPayStatus.cancelled),
        'cancelled',
      );
      expect(
        FinanceEnumCodec.parsePromiseToPayStatus('kept'),
        PromiseToPayStatus.kept,
      );
    });

    test('backend processed status maps to client enum', () {
      expect(
        FinanceEnumCodec.parseRefundStatus('processed'),
        RefundStatus.processed,
      );
    });

    test('installment plan catalog provides annual default', () {
      expect(
        kFinanceInstallmentPlanCatalog.any(
          (plan) => plan.type == InstallmentPlanType.annual,
        ),
        isTrue,
      );
    });

    test('hybrid repository implements FinanceRepository', () {
      final hybrid = HybridFinanceRepository(
        api: ApiFinanceRepository(remote: FinanceRemoteDataSource(Dio())),
      );
      expect(hybrid, isA<FinanceRepository>());
      expect(MockFinanceRepository(), isA<FinanceRepository>());
    });
  });
}
