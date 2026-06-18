import 'package:akshara_erp/core/approvals/approval_exceptions.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/repositories/api/approval/api_approval_repository.dart';
import 'package:akshara_erp/core/repositories/api/approval/remote/approval_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/approval/remote/approval_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/approval/approval_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

void main() {
  group('F2 approval API integration', () {
    const query = RepositoryQuery.demo;
    final fixtures = ApprovalFixtureBuilder();

    test('submit → approve flow uses server audit (no duplicate client audit)', () async {
      final mockRepo = MockApprovalRepository()..reset();
      final submit = fixtures.submitRequest(type: ApprovalRequestType.refund);
      final created = await mockRepo.submit(query: query, request: submit);
      final approved = created.copyWith(
        status: ApprovalStatus.approved,
        decidedAt: DateTime.utc(2026, 6, 17, 12),
        decidedById: 'principal_001',
        decidedByName: 'Dr. Rao',
      );

      final dio = createFakeDio((options) {
        if (options.path == ApprovalApiPaths.entity) {
          return {'data': null};
        }
        if (options.path == ApprovalApiPaths.base && options.method == 'POST') {
          return fixtures.requestEnvelope(created);
        }
        if (options.path == ApprovalApiPaths.approve(created.id)) {
          return fixtures.requestEnvelope(approved);
        }
        if (options.path == ApprovalApiPaths.auditTrail(created.id)) {
          return {
            'data': {
              'items': [
                {
                  'id': 'audit_submit',
                  'approvalRequestId': created.id,
                  'action': 'submitted',
                  'actorId': submit.requesterId,
                  'actorName': submit.requesterName,
                  'occurredAt': created.createdAt.toIso8601String(),
                },
                {
                  'id': 'audit_approve',
                  'approvalRequestId': created.id,
                  'action': 'approved',
                  'actorId': 'principal_001',
                  'actorName': 'Dr. Rao',
                  'occurredAt': approved.decidedAt!.toIso8601String(),
                },
              ],
            },
          };
        }
        return {'data': {}};
      });

      final apiRepo = ApiApprovalRepository(
        remote: ApprovalRemoteDataSource(dio),
      );
      final service = ApprovalCenterService(apiRepo);

      final submitted = await service.submitApprovalRequest(
        query: query,
        request: submit,
      );
      expect(submitted.status, ApprovalStatus.pending);

      final decided = await service.approveRequest(
        query: query,
        request: fixtures.approveRequest(submitted.id),
      );
      expect(decided.status, ApprovalStatus.approved);

      final audit = await service.listAuditEntries(
        query: query,
        approvalRequestId: submitted.id,
      );
      expect(audit.length, 2);
    });

    test('inventory PO self-approve maps to forbidden from API', () async {
      final poId = 'b5000000-0000-4000-8000-000000000099';
      final dio = createFakeDio((options) {
        if (options.path == ApprovalApiPaths.approve(poId)) {
          return {
            'data': null,
            'error': {
              'code': 'FORBIDDEN',
              'message':
                  'Purchase order creator cannot approve their own request: $poId',
            },
          };
        }
        return {'data': {}};
      });

      final apiRepo = ApiApprovalRepository(
        remote: ApprovalRemoteDataSource(dio),
      );

      expect(
        () => apiRepo.approve(
          query: query,
          request: fixtures.approveRequest(poId),
        ),
        throwsA(isA<ApprovalInvalidStateException>()),
      );
    });
  });
}
