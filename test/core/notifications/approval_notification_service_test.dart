import 'package:akshara_erp/core/notifications/approval_notification_service.dart';
import 'package:akshara_erp/core/approvals/approval_models.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApprovalNotificationService — M-D7', () {
    late ApprovalNotificationService service;

    setUp(() {
      service = ApprovalNotificationService.instance..reset();
    });

    test('recordDecision stores last notification for requester', () {
      final request = ApprovalRequest(
        id: 'apr_1',
        type: ApprovalRequestType.examResults,
        status: ApprovalStatus.approved,
        title: 'Math results — Class 8A',
        summary: 'Ready for publish',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
        entityType: 'exam_session',
        entityId: 'exam_math_8a',
        createdAt: DateTime.utc(2026, 6, 1),
      );

      service.recordDecision(request: request, approved: true);

      expect(service.lastNotification?.requesterId, 'teacher_001');
      expect(service.lastNotification?.approved, isTrue);
      expect(service.lastNotification?.title, contains('Math results'));
    });

    test('recordDecision captures rejection comment', () {
      final request = ApprovalRequest(
        id: 'apr_2',
        type: ApprovalRequestType.studentLeave,
        status: ApprovalStatus.rejected,
        title: 'Leave — Ravi Kumar',
        summary: 'Family function',
        requesterId: 'parent_001',
        requesterName: 'Parent Demo',
        entityType: 'student_leave',
        entityId: 'lv_1',
        createdAt: DateTime.utc(2026, 6, 1),
      );

      service.recordDecision(
        request: request,
        approved: false,
        comment: 'Insufficient notice period.',
      );

      expect(service.lastNotification?.approved, isFalse);
      expect(
        service.lastNotification?.comment,
        'Insufficient notice period.',
      );
    });
  });
}
