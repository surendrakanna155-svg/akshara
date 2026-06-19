import 'package:akshara_erp/core/approvals/approval_models.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/leave/student_leave_governance_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_write_store.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/teacher/leave_approvals/teacher_leave_approvals_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ApprovalRequest leaveRequest({required String classLabel}) => ApprovalRequest(
      id: 'apr_1',
      type: ApprovalRequestType.studentLeave,
      status: ApprovalStatus.pending,
      title: 'Ravi — Sick leave',
      summary: 'x',
      requesterId: 'p1',
      requesterName: 'Parent',
      entityType: 'student_leave',
      entityId: 'lv_1',
      payload: {'classLabel': classLabel, 'childName': 'Ravi Kumar'},
      createdAt: DateTime(2026, 6, 19),
    );

void main() {
  test('class teacher owns only their own class\'s student leave', () {
    final req = leaveRequest(classLabel: '8-A');
    expect(classTeacherOwnsLeave(req, '8-A'), isTrue);
    expect(classTeacherOwnsLeave(req, '9-B'), isFalse); // other class
    expect(classTeacherOwnsLeave(req, null), isFalse); // not a class teacher
  });

  test('a non-leave request is never owned as a leave', () {
    final exam = ApprovalRequest(
      id: 'x',
      type: ApprovalRequestType.examResults,
      status: ApprovalStatus.pending,
      title: 't',
      summary: 's',
      requesterId: 'r',
      requesterName: 'n',
      entityType: 'exam_session',
      entityId: 'e',
      payload: const {'classLabel': '8-A'},
      createdAt: DateTime(2026, 6, 19),
    );
    expect(classTeacherOwnsLeave(exam, '8-A'), isFalse);
  });

  test('teacher role can approve student leave', () {
    final perms = RolePermissionMatrix.permissionsFor(ErpRole.teacher);
    expect(perms.contains(Permission.approveStudentLeave), isTrue);
  });

  test('approving a leave updates the parent\'s leave to approved', () {
    final store = MockParentWriteStore.instance;
    store.leaveRequests = [
      const LeaveRequest(
        id: 'lv_1',
        childName: 'Ravi Kumar',
        childClass: '8-A',
        fromDateLabel: '20 Jun',
        toDateLabel: '21 Jun',
        reason: 'Fever',
        type: LeaveType.sick,
        status: LeaveStatus.pending,
        submittedLabel: 'Just now',
        timeline: [],
      ),
    ];

    // This is what the class teacher's approve action triggers downstream.
    StudentLeaveGovernanceStore.instance.applyDecision(
      leaveId: 'lv_1',
      status: LeaveStatus.approved,
      comment: '',
    );

    expect(store.leaveRequests!.first.status, LeaveStatus.approved);
  });
}
