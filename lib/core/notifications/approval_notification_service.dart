import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../approvals/approval_models.dart';
import '../approvals/approval_request_type.dart';

/// In-app notification stub for approval outcomes (M-D7).
class ApprovalDecisionNotification {
  const ApprovalDecisionNotification({
    required this.approvalId,
    required this.requesterId,
    required this.type,
    required this.approved,
    required this.title,
    this.comment,
  });

  final String approvalId;
  final String requesterId;
  final ApprovalRequestType type;
  final bool approved;
  final String title;
  final String? comment;
}

class ApprovalNotificationService {
  ApprovalNotificationService._();

  static final ApprovalNotificationService instance =
      ApprovalNotificationService._();

  ApprovalDecisionNotification? lastNotification;

  void recordDecision({
    required ApprovalRequest request,
    required bool approved,
    String? comment,
  }) {
    lastNotification = ApprovalDecisionNotification(
      approvalId: request.id,
      requesterId: request.requesterId,
      type: request.type,
      approved: approved,
      title: request.title,
      comment: comment,
    );
  }

  void reset() => lastNotification = null;
}

final approvalNotificationServiceProvider =
    Provider<ApprovalNotificationService>(
  (_) => ApprovalNotificationService.instance,
);

/// Feature flag: `--dart-define=APPROVAL_NOTIFICATIONS_ENABLED=false`
final approvalNotificationsEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'APPROVAL_NOTIFICATIONS_ENABLED',
    defaultValue: true,
  ),
);
