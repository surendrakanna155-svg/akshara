import 'package:akshara_erp/core/approvals/approval_audit.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_exceptions.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/approval/approval_fixture_builder.dart';

const _query = RepositoryQuery.demo;
final _fixtures = ApprovalFixtureBuilder();

void main() {
  group('ApprovalCenterService', () {
    late MockApprovalRepository repository;
    late ApprovalCenterService service;

    setUp(() {
      repository = MockApprovalRepository()..reset();
      service = ApprovalCenterService(repository);
    });

    test('submitApprovalRequest creates pending item and audit trail', () async {
      final submit = _fixtures.submitRequest();
      final created = await service.submitApprovalRequest(
        query: _query,
        request: submit,
      );

      expect(created.status, ApprovalStatus.pending);

      final audit = await service.listAuditEntries(
        query: _query,
        approvalRequestId: created.id,
      );
      expect(audit.length, 1);
      expect(audit.first.action, ApprovalAuditAction.submitted);
      expect(audit.first.actorId, submit.requesterId);
    });

    test('duplicate submit returns existing pending without second audit', () async {
      final submit = _fixtures.submitRequest();
      final first = await service.submitApprovalRequest(
        query: _query,
        request: submit,
      );
      final second = await service.submitApprovalRequest(
        query: _query,
        request: submit,
      );

      expect(second.id, first.id);

      final pending = await service.listPending(query: _query);
      expect(pending.length, 1);

      final audit = await service.listAuditEntries(
        query: _query,
        approvalRequestId: first.id,
      );
      expect(audit.length, 1);
    });

    test('approveRequest records approved audit entry', () async {
      final created = await service.submitApprovalRequest(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      final approved = await service.approveRequest(
        query: _query,
        request: _fixtures.approveRequest(created.id),
      );

      expect(approved.status, ApprovalStatus.approved);

      final audit = await service.listAuditEntries(
        query: _query,
        approvalRequestId: created.id,
      );
      expect(audit.length, 2);
      expect(audit.last.action, ApprovalAuditAction.approved);
    });

    test('rejectRequest requires comment at service layer', () async {
      final created = await service.submitApprovalRequest(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      expect(
        () => service.rejectRequest(
          query: _query,
          request: _fixtures.rejectRequest(created.id, comment: ''),
        ),
        throwsA(isA<ApprovalRejectCommentRequiredException>()),
      );
    });

    test('rejectRequest records rejected audit entry', () async {
      final created = await service.submitApprovalRequest(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      await service.rejectRequest(
        query: _query,
        request: _fixtures.rejectRequest(created.id),
      );

      final audit = await service.listAuditEntries(
        query: _query,
        approvalRequestId: created.id,
      );
      expect(audit.last.action, ApprovalAuditAction.rejected);
    });

    test('cancelRequest records cancelled audit entry', () async {
      final created = await service.submitApprovalRequest(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      final cancelled = await service.cancelRequest(
        query: _query,
        request: _fixtures.cancelRequest(created.id),
      );

      expect(cancelled.status, ApprovalStatus.cancelled);

      final audit = await service.listAuditEntries(
        query: _query,
        approvalRequestId: created.id,
      );
      expect(audit.last.action, ApprovalAuditAction.cancelled);
    });

    test('listByFilter delegates to repository', () async {
      await service.submitApprovalRequest(
        query: _query,
        request: _fixtures.submitRequest(entityId: 'exam_filter_a'),
      );

      final filtered = await service.listByFilter(
        query: _query,
        filter: _fixtures.pendingExamFilter(),
      );

      expect(filtered.length, 1);
      expect(filtered.first.entityId, 'exam_filter_a');
    });
  });
}
