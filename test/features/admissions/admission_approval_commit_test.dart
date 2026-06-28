import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW1 · QA-J-032 — Principal admission approval is a real WRITE: a pending
/// application is approved and the decision persists (re-read no longer pending).
/// Closes the gap that no explicit approve write + applicant-state change was
/// asserted. (The downstream finance hand-off is a separate sendToFinance step;
/// the approval UI is covered under QW3/QW7.)
void main() {
  test('QA-J-032: approving a pending admission persists the approved decision',
      () async {
    final repo = MockAdmissionsRepository();
    const query = RepositoryQuery.demo;

    final queue = await repo.getApprovalQueue(query: query);
    final pending = queue.items.firstWhere(
      (i) => i.decision == ApprovalDecision.pending,
    );

    final approved = await repo.approveAdmission(
      query: query,
      approvalId: pending.id,
      request: const ApprovalDecisionRequest(comment: 'QW1 verified approval'),
    );
    expect(approved.decision, ApprovalDecision.approved);

    // Persistence: the item is no longer pending on re-read.
    final reread = await repo.getApprovalQueue(query: query);
    final stillPending = reread.items.any(
      (i) => i.id == pending.id && i.decision == ApprovalDecision.pending,
    );
    expect(stillPending, isFalse,
        reason: 'approved item must leave the pending queue');
  });
}
