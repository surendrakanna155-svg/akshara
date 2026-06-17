import '../../approvals/approval_models.dart';
import '../../repositories/repository_query.dart';

/// Post-decision side effects for a unified approval request (M-D3+).
abstract class ApprovalTypeAdapter {
  /// Runs after the approval record is marked approved.
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  });

  /// Runs after the approval record is marked rejected.
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  });

  /// Optional detail lines for the principal detail panel.
  Map<String, String> enrichDetail(ApprovalRequest request);
}
