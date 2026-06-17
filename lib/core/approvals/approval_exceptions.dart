/// Thrown when a reject decision is attempted without a comment.
class ApprovalRejectCommentRequiredException implements Exception {
  ApprovalRejectCommentRequiredException(this.approvalId);

  final String approvalId;

  @override
  String toString() =>
      'ApprovalRejectCommentRequiredException: comment required for $approvalId';
}

/// Thrown when an action is attempted on a non-pending approval.
class ApprovalInvalidStateException implements Exception {
  ApprovalInvalidStateException({
    required this.approvalId,
    required this.currentStatus,
    required this.action,
  });

  final String approvalId;
  final String currentStatus;
  final String action;

  @override
  String toString() =>
      'ApprovalInvalidStateException: cannot $action $approvalId (status=$currentStatus)';
}

/// Thrown when an approval request cannot be found.
class ApprovalNotFoundException implements Exception {
  ApprovalNotFoundException(this.approvalId);

  final String approvalId;

  @override
  String toString() => 'ApprovalNotFoundException: $approvalId not found';
}
