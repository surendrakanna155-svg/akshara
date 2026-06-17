import 'package:akshara_erp/core/approvals/adapters/finance_approval_adapters.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/finance/finance_approval_governance_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('Finance approval integration — M-D5', () {
    late MockApprovalRepository repository;
    late ApprovalCenterService service;
    late FinanceApprovalGovernanceStore store;

    setUp(() {
      repository = MockApprovalRepository();
      service = ApprovalCenterService(repository);
      store = FinanceApprovalGovernanceStore.instance..reset();
    });

    test('fee structure approval activates structure in governance store', () async {
      const structureId = 'fs_test_1';
      final adapter = FeeStructureApprovalAdapter(store: store);

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        feeStructureId: structureId,
        requesterId: 'finance_001',
        requesterName: 'Finance Admin',
        title: 'Activate fee structure — 2026-27',
        summary: 'Class 1–12',
        payload: const {'name': '2026-27 Standard'},
      );
      expect(pending.status, ApprovalStatus.pending);

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(store.activatedFeeStructureIds, contains(structureId));
    });

    test('concession approval applies concession side effect', () async {
      const concessionId = 'concession_test';
      final adapter = FeeConcessionApprovalAdapter(store: store);

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        concessionId: concessionId,
        requesterId: 'finance_001',
        requesterName: 'Finance Admin',
        title: 'Fee concession — Ananya',
        summary: '₹5,000 · merit scholarship',
        payload: const {
          'studentName': 'Ananya',
          'amount': '₹5,000',
          'reason': 'merit scholarship',
        },
      );

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(store.appliedConcessionIds, contains(concessionId));
    });

    test('refund approval records approved refund id', () async {
      const refundId = 'refund_test';
      final adapter = RefundApprovalAdapter(store: store);

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        refundId: refundId,
        requesterId: 'finance_001',
        requesterName: 'Finance Admin',
        title: 'Refund — Ravi Kumar',
        summary: '₹2,000 · duplicate payment',
        payload: const {
          'studentName': 'Ravi Kumar',
          'amount': '₹2,000',
          'reason': 'duplicate payment',
        },
      );

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(store.approvedRefundIds, contains(refundId));
    });
  });
}
