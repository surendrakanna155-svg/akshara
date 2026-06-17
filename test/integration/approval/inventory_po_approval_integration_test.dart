import 'package:akshara_erp/core/approvals/adapters/inventory_po_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_models.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/inventory/inventory_po_governance_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('Inventory PO approval integration — M-D6', () {
    late MockApprovalRepository repository;
    late ApprovalCenterService service;
    late InventoryPoApprovalAdapter adapter;
    late InventoryPoGovernanceStore store;

    setUp(() {
      repository = MockApprovalRepository();
      service = ApprovalCenterService(repository);
      store = InventoryPoGovernanceStore.instance..reset();
      adapter = InventoryPoApprovalAdapter(store: store);
    });

    test('submit → approve marks PO approved in governance store', () async {
      const orderId = 'po_test_1';

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        orderId: orderId,
        requesterId: 'storekeeper_001',
        requesterName: 'Storekeeper',
        title: 'Approve PO — PO-2026-1001',
        summary: 'Stationery · ₹25,000',
        payload: const {
          'poNumber': 'PO-2026-1001',
          'vendorName': 'Stationery Co',
          'totalAmount': '₹25,000',
          'requestedBy': 'Storekeeper',
        },
      );
      expect(pending.status, ApprovalStatus.pending);
      expect(store.creatorByOrderId[orderId], 'storekeeper_001');

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(store.isApproved(orderId), isTrue);
    });

    test('creator cannot approve own PO', () {
      store.registerOrder(orderId: 'po_self', requestedBy: 'storekeeper_001');

      expect(
        () => InventoryPoApprovalAdapter.assertApproverNotCreator(
          request: ApprovalRequest(
            id: 'apr_test',
            type: ApprovalRequestType.inventoryPo,
            status: ApprovalStatus.pending,
            title: 'PO',
            summary: 'Test',
            requesterId: 'storekeeper_001',
            requesterName: 'Storekeeper',
            entityType: InventoryPoApprovalAdapter.entityType,
            entityId: 'po_self',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
          actorId: 'storekeeper_001',
        ),
        throwsA(isA<ApiFailureException>()),
      );
    });
  });
}
