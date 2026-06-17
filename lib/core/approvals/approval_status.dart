/// Lifecycle status for a cross-module approval request.
enum ApprovalStatus {
  pending,
  approved,
  rejected,
  cancelled;

  String get label => switch (this) {
        ApprovalStatus.pending => 'Pending',
        ApprovalStatus.approved => 'Approved',
        ApprovalStatus.rejected => 'Rejected',
        ApprovalStatus.cancelled => 'Cancelled',
      };

  bool get isTerminal =>
      this == ApprovalStatus.approved ||
      this == ApprovalStatus.rejected ||
      this == ApprovalStatus.cancelled;
}
