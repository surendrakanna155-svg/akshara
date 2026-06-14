import 'management_models.dart';

class ResolveManagementApprovalRequest {
  const ResolveManagementApprovalRequest({
    required this.approvalId,
    required this.status,
  });

  final String approvalId;
  final ManagementApprovalStatus status;
}
