import '../../repositories/repository_query.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import 'approval_type_adapter.dart';
import 'exam_results_approval_adapter.dart';

/// Dispatches post-decision hooks to module adapters (M-D3+).
class ApprovalAdapterRegistry {
  const ApprovalAdapterRegistry._();

  static ApprovalTypeAdapter? adapterFor(ApprovalRequestType type) =>
      switch (type) {
        ApprovalRequestType.examResults => ExamResultsApprovalAdapter(),
        _ => null,
      };

  static void dispatchApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    adapterFor(request.type)?.onApproved(query: query, request: request);
  }

  static void dispatchRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    adapterFor(request.type)?.onRejected(
          query: query,
          request: request,
          comment: comment,
        );
  }

  static Map<String, String> enrichDetail(ApprovalRequest request) {
    return adapterFor(request.type)?.enrichDetail(request) ?? const {};
  }
}
