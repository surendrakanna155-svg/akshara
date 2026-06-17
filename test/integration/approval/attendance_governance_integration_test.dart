import 'package:akshara_erp/core/approvals/adapters/staff_leave_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/adapters/student_leave_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/leave/staff_leave_governance_store.dart';
import 'package:akshara_erp/core/leave/student_leave_governance_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('Attendance governance integration — M-D4', () {
    late MockApprovalRepository repository;
    late ApprovalCenterService service;
    late StudentLeaveApprovalAdapter studentAdapter;
    late StaffLeaveApprovalAdapter staffAdapter;

    setUp(() {
      repository = MockApprovalRepository();
      service = ApprovalCenterService(repository);
      studentAdapter = StudentLeaveApprovalAdapter();
      staffAdapter = StaffLeaveApprovalAdapter();
      StudentLeaveGovernanceStore.instance.reset();
      StaffLeaveGovernanceStore.instance.reset();

      MockParentWriteStore.instance.leaveRequests = [
        LeaveRequest(
          id: 'lv_test_1',
          childName: 'Ravi Kumar',
          childClass: 'Class 8-A',
          fromDateLabel: '20 Jun 2026',
          toDateLabel: '22 Jun 2026',
          reason: 'Family function',
          type: LeaveType.personal,
          status: LeaveStatus.pending,
          submittedLabel: '18 Jun 2026',
          timeline: const [
            LeaveTimelineStep(
              label: 'Submitted',
              dateLabel: 'Complete',
              isComplete: true,
            ),
            LeaveTimelineStep(
              label: 'Principal review',
              dateLabel: 'Pending',
              isComplete: false,
            ),
          ],
        ),
      ];

      MockHrWriteStore.instance.leaveRequests = [
        HrLeaveRequest(
          id: 'lv_req_test',
          employeeId: 'HR-EMP-1',
          employeeName: 'Anita Rao',
          department: HrDepartment.academics,
          leaveType: HrLeaveType.casual,
          fromDate: '20 Jun 2026',
          toDate: '21 Jun 2026',
          days: 2,
          status: HrLeaveStatus.pending,
          approver: '—',
          reason: 'Medical appointment',
        ),
      ];
    });

    test('student leave submit → approve updates mock store', () async {
      final pending = await studentAdapter.submitForApproval(
        service: service,
        query: _query,
        leaveId: 'lv_test_1',
        requesterId: 'parent_001',
        requesterName: 'Parent Demo',
        title: 'Leave — Ravi Kumar',
        summary: 'Family function',
        payload: const {
          'childName': 'Ravi Kumar',
          'classLabel': 'Class 8-A',
        },
      );
      expect(pending.status, ApprovalStatus.pending);

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      studentAdapter.onApproved(query: _query, request: approved);

      final leave = MockParentWriteStore.instance.leaveRequests!.first;
      expect(leave.status, LeaveStatus.approved);
    });

    test('staff leave reject stores principal comment', () async {
      final pending = await staffAdapter.submitForApproval(
        service: service,
        query: _query,
        leaveId: 'lv_req_test',
        requesterId: 'hr_admin',
        requesterName: 'HR Admin',
        title: 'Staff leave — Anita Rao',
        summary: 'Medical appointment',
        payload: const {'employeeName': 'Anita Rao'},
      );

      final rejected = await service.rejectRequest(
        query: _query,
        request: RejectApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
          comment: 'Insufficient substitute coverage.',
        ),
      );
      staffAdapter.onRejected(
        query: _query,
        request: rejected,
        comment: 'Insufficient substitute coverage.',
      );

      expect(
        StaffLeaveGovernanceStore.instance.rejectionCommentFor('lv_req_test'),
        'Insufficient substitute coverage.',
      );
      expect(
        MockHrWriteStore.instance.leaveRequests!.first.status,
        HrLeaveStatus.rejected,
      );
    });
  });
}
