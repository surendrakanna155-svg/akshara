import 'package:akshara_erp/core/repositories/api/parent/dto/parent_leave_submit_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/parent/dto/parent_payment_request_dto.dart';
import 'package:akshara_erp/core/repositories/interfaces/parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/parent_requests.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Parent write DTO serialization', () {
    test('leave submit request uses snake_case keys', () {
      const request = ParentLeaveSubmitRequest(
        childId: 'child_ravi',
        fromDateLabel: '12 Jun 2026',
        toDateLabel: '12 Jun 2026',
        reason: 'Doctor advised rest.',
        type: LeaveType.sick,
      );
      final json = ParentLeaveSubmitRequestDto.fromDomain(request).toJson();
      expect(json['child_id'], 'child_ravi');
      expect(json['type'], 'sick');
    });

    test('payment initiate request serializes method and amount', () {
      final json = ParentPaymentInitiateRequestDto.fromDomain(
        const ParentPaymentInitiateRequest(
          installmentId: 'term_2',
          paymentMethod: PaymentMethod.upi,
          amount: 4200,
        ),
      ).toJson();
      expect(json['installment_id'], 'term_2');
      expect(json['payment_method'], 'upi');
      expect(json['amount'], 4200);
    });

    test('payment confirm request serializes intent id', () {
      final json = ParentPaymentConfirmRequestDto.fromDomain(
        const ParentPaymentConfirmRequest(
          paymentIntentId: 'pi_501',
          transactionRef: 'TXN-123',
        ),
      ).toJson();
      expect(json['payment_intent_id'], 'pi_501');
      expect(json['transaction_ref'], 'TXN-123');
    });
  });

  group('Mock parent write repository', () {
    late MockParentRepository repo;

    setUp(() {
      repo = MockParentRepository();
    });

    test('implements all write methods on ParentRepository', () {
      expect(repo, isA<ParentRepository>());
    });

    test('submitLeaveRequest returns persisted leave in getLeaveHistory', () async {
      final created = await repo.submitLeaveRequest(
        query: kQuery,
        request: const ParentLeaveSubmitRequest(
          childId: 'child_ravi',
          fromDateLabel: '12 Jun 2026',
          toDateLabel: '12 Jun 2026',
          reason: 'Doctor advised rest for one day.',
        ),
      );
      final history = await repo.getLeaveHistory(query: kQuery);
      expect(history.any((item) => item.id == created.id), isTrue);
      expect(created.status, LeaveStatus.pending);
    });

    test('initiatePayment and confirmPayment complete payment flow', () async {
      final initiation = await repo.initiatePayment(
        query: kQuery,
        request: const ParentPaymentInitiateRequest(
          installmentId: 'term_2',
          paymentMethod: PaymentMethod.upi,
          amount: 4200,
        ),
      );
      expect(initiation.status, 'pending');

      final confirmation = await repo.confirmPayment(
        query: kQuery,
        request: ParentPaymentConfirmRequest(
          paymentIntentId: initiation.paymentIntentId,
          transactionRef: 'TXN-123',
        ),
      );
      expect(confirmation.paidAmount, 4200);
      expect(confirmation.paymentMethod, PaymentMethod.upi);
    });
  });
}
