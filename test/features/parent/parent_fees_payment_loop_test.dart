import 'package:akshara_erp/core/repositories/mock/mock_fee_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/parent_requests.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;

  setUp(() => MockFeeStore.instance.reset());

  test('paying a term marks it paid, lowers the dues, and adds a receipt',
      () async {
    final repo = MockParentRepository();

    final before = await repo.getFees(query: query);
    final term2Before =
        before.installments.firstWhere((i) => i.id == 'term_2');
    expect(term2Before.status, FeeInstallmentStatus.due);

    final init = await repo.initiatePayment(
      query: query,
      request: const ParentPaymentInitiateRequest(
        installmentId: 'term_2',
        paymentMethod: PaymentMethod.upi,
        amount: 4200,
      ),
    );
    await repo.confirmPayment(
      query: query,
      request: ParentPaymentConfirmRequest(
        paymentIntentId: init.paymentIntentId,
        transactionRef: 'txn_test',
      ),
    );

    final after = await repo.getFees(query: query);
    expect(
      after.installments.firstWhere((i) => i.id == 'term_2').status,
      FeeInstallmentStatus.paid,
    );
    expect(after.pendingAmount, before.pendingAmount - 4200);
    expect(after.paidAmount, before.paidAmount + 4200);
    expect(after.paymentHistory.first.amount, 4200);

    final receipts = await repo.getReceipts(query: query);
    expect(
      receipts.any((r) => r.receiptNumber == 'APS-2026-TERM_2'),
      isTrue,
    );
  });

  test('fees start from the seeded sample until a payment is made', () async {
    final repo = MockParentRepository();
    final fees = await repo.getFees(query: query);
    expect(fees.pendingAmount, 4200);
    expect(fees.paidAmount, 18800);
  });
}
