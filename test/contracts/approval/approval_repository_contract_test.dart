import 'package:akshara_erp/core/approvals/approval_audit.dart';
import 'package:akshara_erp/core/approvals/approval_exceptions.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/repositories/api/api_exception.dart';
import 'package:akshara_erp/core/repositories/api/approval/api_approval_repository.dart';
import 'package:akshara_erp/core/repositories/interfaces/approval_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import 'approval_fixture_builder.dart';

const _query = RepositoryQuery.demo;
final _fixtures = ApprovalFixtureBuilder();

void main() {
  group('Approval repository contract', () {
    late MockApprovalRepository mockRepo;
    late ApiApprovalRepository apiRepo;

    setUp(() {
      mockRepo = MockApprovalRepository()..reset();
      apiRepo = ApiApprovalRepository();
    });

    test('mock and api implement ApprovalRepository', () {
      expect(mockRepo, isA<ApprovalRepository>());
      expect(apiRepo, isA<ApprovalRepository>());
    });

    test('submit creates pending request scoped to tenant', () async {
      final submit = _fixtures.submitRequest();
      final created = await mockRepo.submit(query: _query, request: submit);

      expect(created.status, ApprovalStatus.pending);
      expect(created.type, submit.type);
      expect(created.entityId, submit.entityId);
      expect(created.tenantId, _query.tenantId);
      expect(created.schoolId, _query.schoolId);

      final pending = await mockRepo.listPending(query: _query);
      expect(pending.length, 1);
      expect(pending.first.id, created.id);
    });

    test('findPendingByEntity returns open request only', () async {
      final submit = _fixtures.submitRequest();
      final created = await mockRepo.submit(query: _query, request: submit);

      final found = await mockRepo.findPendingByEntity(
        query: _query,
        type: submit.type,
        entityType: submit.entityType,
        entityId: submit.entityId,
      );
      expect(found?.id, created.id);

      await mockRepo.approve(
        query: _query,
        request: _fixtures.approveRequest(created.id),
      );

      final afterApprove = await mockRepo.findPendingByEntity(
        query: _query,
        type: submit.type,
        entityType: submit.entityType,
        entityId: submit.entityId,
      );
      expect(afterApprove, isNull);
    });

    test('approve transitions pending to approved', () async {
      final created = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      final approved = await mockRepo.approve(
        query: _query,
        request: _fixtures.approveRequest(created.id),
      );

      expect(approved.status, ApprovalStatus.approved);
      expect(approved.decidedById, 'principal_001');
      expect(approved.decidedAt, isNotNull);
    });

    test('reject requires non-empty comment', () async {
      final created = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      expect(
        () => mockRepo.reject(
          query: _query,
          request: _fixtures.rejectRequest(created.id, comment: '   '),
        ),
        throwsA(isA<ApprovalRejectCommentRequiredException>()),
      );
    });

    test('reject transitions pending to rejected with comment', () async {
      final created = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      final rejected = await mockRepo.reject(
        query: _query,
        request: _fixtures.rejectRequest(created.id),
      );

      expect(rejected.status, ApprovalStatus.rejected);
      expect(rejected.decisionComment, isNotEmpty);
    });

    test('cancel transitions pending to cancelled', () async {
      final created = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      final cancelled = await mockRepo.cancel(
        query: _query,
        request: _fixtures.cancelRequest(created.id),
      );

      expect(cancelled.status, ApprovalStatus.cancelled);
    });

    test('cannot approve non-pending request', () async {
      final created = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(),
      );
      await mockRepo.approve(
        query: _query,
        request: _fixtures.approveRequest(created.id),
      );

      expect(
        () => mockRepo.approve(
          query: _query,
          request: _fixtures.approveRequest(created.id),
        ),
        throwsA(isA<ApprovalInvalidStateException>()),
      );
    });

    test('listByFilter respects status and type', () async {
      await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(entityId: 'exam_a'),
      );
      final second = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(entityId: 'exam_b'),
      );
      await mockRepo.approve(
        query: _query,
        request: _fixtures.approveRequest(second.id),
      );

      final pendingExams = await mockRepo.listByFilter(
        query: _query,
        filter: _fixtures.pendingExamFilter(),
      );

      expect(pendingExams.length, 1);
      expect(pendingExams.first.entityId, 'exam_a');
    });

    test('recordAuditEntry stores scoped audit rows', () async {
      final created = await mockRepo.submit(
        query: _query,
        request: _fixtures.submitRequest(),
      );

      await mockRepo.recordAuditEntry(
        query: _query,
        entry: _fixtures.auditEntry(
          approvalRequestId: created.id,
          action: ApprovalAuditAction.submitted,
        ),
      );

      final audit = await mockRepo.listAuditEntries(
        query: _query,
        approvalRequestId: created.id,
      );
      expect(audit.length, 1);
      expect(audit.first.action, ApprovalAuditAction.submitted);
    });

    test('api repository throws ApiNotConnectedException', () async {
      expect(
        () => apiRepo.listPending(query: _query),
        throwsA(isA<ApiNotConnectedException>()),
      );
    });
  });
}
