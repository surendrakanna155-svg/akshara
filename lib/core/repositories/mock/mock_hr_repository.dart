import 'package:flutter/material.dart';

import '../../../features/auth/auth_provider.dart';
import '../../../features/hr/hr_models.dart';
import '../../../features/hr/hr_report_models.dart';
import '../../../features/hr/hr_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/hr_repository.dart';
import '../paginated_result.dart';
import '../repository_query.dart';
import '../../tenant/tenant_mock_scope.dart';
import 'mock_hr_write_store.dart';

class MockHrRepository implements HrRepository {
  static const _employees = [
    HrEmployee(
      id: 'HR-EMP-101',
      name: kMockTeacherName,
      employeeCode: 'EMP-101',
      department: HrDepartment.academics,
      role: HrEmployeeRole.teacher,
      designation: 'Mathematics Teacher',
      email: 'priya.sharma@akshara.edu',
      phone: '+91 98765 43210',
      joinDate: '2019-06-01',
      status: HrEmployeeStatus.active,
      teacherAppLinked: true,
      classLabel: '8-B',
    ),
    HrEmployee(
      id: 'HR-EMP-102',
      name: 'Mrs. Rao',
      employeeCode: 'EMP-102',
      department: HrDepartment.academics,
      role: HrEmployeeRole.teacher,
      designation: 'English Teacher',
      email: 'mrs.rao@akshara.edu',
      phone: '+91 98765 43211',
      joinDate: '2018-04-15',
      status: HrEmployeeStatus.active,
      teacherAppLinked: true,
      classLabel: '7-A',
    ),
    HrEmployee(
      id: 'HR-EMP-103',
      name: 'Mr. Patel',
      employeeCode: 'EMP-103',
      department: HrDepartment.academics,
      role: HrEmployeeRole.teacher,
      designation: 'Science Teacher',
      email: 'mr.patel@akshara.edu',
      phone: '+91 98765 43212',
      joinDate: '2020-01-10',
      status: HrEmployeeStatus.active,
      teacherAppLinked: true,
      classLabel: '10-A',
    ),
    HrEmployee(
      id: 'HR-EMP-104',
      name: 'Ramesh Kumar',
      employeeCode: 'EMP-104',
      department: HrDepartment.transport,
      role: HrEmployeeRole.driver,
      designation: 'Bus Driver',
      email: 'ramesh.kumar@akshara.edu',
      phone: '+91 98765 43213',
      joinDate: '2017-08-20',
      status: HrEmployeeStatus.active,
      teacherAppLinked: false,
    ),
    HrEmployee(
      id: 'HR-EMP-105',
      name: 'Kavitha Menon',
      employeeCode: 'EMP-105',
      department: HrDepartment.hr,
      role: HrEmployeeRole.admin,
      designation: 'HR Manager',
      email: 'kavitha.menon@akshara.edu',
      phone: '+91 98765 43214',
      joinDate: '2016-03-01',
      status: HrEmployeeStatus.active,
      teacherAppLinked: false,
    ),
    HrEmployee(
      id: 'HR-EMP-106',
      name: 'Rajesh Iyer',
      employeeCode: 'EMP-106',
      department: HrDepartment.administration,
      role: HrEmployeeRole.principal,
      designation: 'Principal',
      email: 'rajesh.iyer@akshara.edu',
      phone: '+91 98765 43215',
      joinDate: '2015-01-01',
      status: HrEmployeeStatus.active,
      teacherAppLinked: false,
    ),
    HrEmployee(
      id: 'HR-EMP-107',
      name: 'Anil Verma',
      employeeCode: 'EMP-107',
      department: HrDepartment.finance,
      role: HrEmployeeRole.staff,
      designation: 'Accounts Officer',
      email: 'anil.verma@akshara.edu',
      phone: '+91 98765 43216',
      joinDate: '2021-07-01',
      status: HrEmployeeStatus.active,
      teacherAppLinked: false,
    ),
    HrEmployee(
      id: 'HR-EMP-108',
      name: 'Sunita Nair',
      employeeCode: 'EMP-108',
      department: HrDepartment.academics,
      role: HrEmployeeRole.teacher,
      designation: 'Hindi Teacher',
      email: 'sunita.nair@akshara.edu',
      phone: '+91 98765 43217',
      joinDate: '2022-06-15',
      status: HrEmployeeStatus.onLeave,
      teacherAppLinked: true,
      classLabel: '6-C',
    ),
  ];

  static const _attendanceRecords = [
    HrAttendanceRecord(
      id: 'att_1',
      employeeId: 'HR-EMP-101',
      employeeName: kMockTeacherName,
      department: HrDepartment.academics,
      date: '2026-06-06',
      checkIn: '8:02 AM',
      checkOut: '3:45 PM',
      status: HrAttendanceStatus.present,
      geoVerified: true,
      faceVerified: true,
    ),
    HrAttendanceRecord(
      id: 'att_2',
      employeeId: 'HR-EMP-102',
      employeeName: 'Mrs. Rao',
      department: HrDepartment.academics,
      date: '2026-06-06',
      checkIn: '8:15 AM',
      checkOut: '3:50 PM',
      status: HrAttendanceStatus.late,
      geoVerified: true,
      faceVerified: true,
    ),
    HrAttendanceRecord(
      id: 'att_3',
      employeeId: 'HR-EMP-103',
      employeeName: 'Mr. Patel',
      department: HrDepartment.academics,
      date: '2026-06-06',
      checkIn: '7:55 AM',
      checkOut: '3:40 PM',
      status: HrAttendanceStatus.present,
      geoVerified: true,
      faceVerified: true,
    ),
    HrAttendanceRecord(
      id: 'att_4',
      employeeId: 'HR-EMP-104',
      employeeName: 'Ramesh Kumar',
      department: HrDepartment.transport,
      date: '2026-06-06',
      checkIn: '6:30 AM',
      checkOut: '4:15 PM',
      status: HrAttendanceStatus.present,
      geoVerified: true,
      faceVerified: false,
    ),
    HrAttendanceRecord(
      id: 'att_5',
      employeeId: 'HR-EMP-108',
      employeeName: 'Sunita Nair',
      department: HrDepartment.academics,
      date: '2026-06-06',
      checkIn: '—',
      checkOut: '—',
      status: HrAttendanceStatus.onLeave,
      geoVerified: false,
      faceVerified: false,
    ),
    HrAttendanceRecord(
      id: 'att_6',
      employeeId: 'HR-EMP-107',
      employeeName: 'Anil Verma',
      department: HrDepartment.finance,
      date: '2026-06-06',
      checkIn: '9:05 AM',
      checkOut: '5:30 PM',
      status: HrAttendanceStatus.present,
      geoVerified: true,
      faceVerified: true,
    ),
  ];

  @override
  Future<HrDashboardData> getDashboard({required RepositoryQuery query}) async {
    return const HrDashboardData(
      kpis: [
        HrKpi(
          id: 'total_employees',
          value: '148',
          label: 'Total Employees',
          icon: Icons.groups_outlined,
          accentName: 'primary',
        ),
        HrKpi(
          id: 'present_today',
          value: '142',
          label: 'Present Today',
          icon: Icons.fact_check_outlined,
          accentName: 'success',
        ),
        HrKpi(
          id: 'on_leave',
          value: '6',
          label: 'On Leave',
          icon: Icons.event_busy_outlined,
          accentName: 'warning',
        ),
        HrKpi(
          id: 'open_positions',
          value: '4',
          label: 'Open Positions',
          icon: Icons.person_search_outlined,
          accentName: 'primary',
        ),
        HrKpi(
          id: 'avg_attendance',
          value: '96%',
          label: 'Avg Attendance (MTD)',
          icon: Icons.trending_up_outlined,
          accentName: 'success',
          detail: 'Feeds Management MG-06 teacher attendance KPI',
        ),
        HrKpi(
          id: 'reviews_due',
          value: '12',
          label: 'Reviews Due',
          icon: Icons.star_outline,
          accentName: 'warning',
        ),
      ],
      headcountTrend: [
        HrTrendPoint(label: 'Jan', amountLakhs: 14.2, targetLakhs: 14.0),
        HrTrendPoint(label: 'Feb', amountLakhs: 14.4, targetLakhs: 14.0),
        HrTrendPoint(label: 'Mar', amountLakhs: 14.6, targetLakhs: 14.5),
        HrTrendPoint(label: 'Apr', amountLakhs: 14.8, targetLakhs: 14.5),
        HrTrendPoint(label: 'May', amountLakhs: 14.8, targetLakhs: 15.0),
        HrTrendPoint(label: 'Jun', amountLakhs: 14.8, targetLakhs: 15.0),
      ],
      attendanceTrend: [
        HrTrendPoint(label: 'W1', amountLakhs: 94.0, targetLakhs: 95.0),
        HrTrendPoint(label: 'W2', amountLakhs: 95.5, targetLakhs: 95.0),
        HrTrendPoint(label: 'W3', amountLakhs: 96.2, targetLakhs: 95.0),
        HrTrendPoint(label: 'W4', amountLakhs: 96.0, targetLakhs: 95.0),
      ],
      pendingLeave: [
        HrPendingLeaveItem(
          id: 'lv_1',
          employeeName: 'Sunita Nair',
          leaveType: HrLeaveType.sick,
          days: 3,
          submittedOn: '2026-06-04',
        ),
        HrPendingLeaveItem(
          id: 'lv_2',
          employeeName: 'Mrs. Rao',
          leaveType: HrLeaveType.casual,
          days: 1,
          submittedOn: '2026-06-05',
        ),
        HrPendingLeaveItem(
          id: 'lv_3',
          employeeName: 'Anil Verma',
          leaveType: HrLeaveType.earned,
          days: 2,
          submittedOn: '2026-06-05',
        ),
      ],
      recruitmentSnapshot: [
        HrCandidate(
          id: 'cand_1',
          name: 'Deepa Krishnan',
          role: 'Physics Teacher',
          department: HrDepartment.academics,
          appliedOn: '2026-05-28',
          stage: HrRecruitmentStage.interview,
          experience: '6 years',
          source: 'Referral',
        ),
        HrCandidate(
          id: 'cand_2',
          name: 'Vikram Singh',
          role: 'Lab Assistant',
          department: HrDepartment.academics,
          appliedOn: '2026-06-01',
          stage: HrRecruitmentStage.screening,
          experience: '2 years',
          source: 'Job portal',
        ),
      ],
      aiInsight:
          'Teacher attrition risk elevated in Mathematics — review workload for Priya Sharma (Class 8-B) and cross-check Management performance KPIs.',
      managementKpiNote:
          'Teacher attendance 96% MTD feeds Management dashboard (MG-01 teacher_avg KPI).',
    );
  }

  @override
  Future<PaginatedResult<HrEmployee>> getEmployees({
    required RepositoryQuery query,
  }) async {
    final employees = await _loadEmployees();
    return PaginatedResult.fromItems(
      TenantMockScope.filter(
        query: query,
        items: employees,
      ),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<HrEmployeeDetail?> getEmployeeDetail({required RepositoryQuery query, required String employeeId}) async {
    final employees = await _loadEmployees();
    final matches = employees.where((e) => e.id == employeeId);
    if (matches.isEmpty) return null;
    final employee = matches.first;

    return HrEmployeeDetail(
      employee: employee,
      reportingManager: employee.role == HrEmployeeRole.principal
          ? 'Board of Trustees'
          : 'Rajesh Iyer (Principal)',
      address: 'Hyderabad, Telangana',
      emergencyContact: '+91 90000 12345',
      leaveBalances: const [
        HrEmployeeLeaveBalance(
          leaveType: HrLeaveType.casual,
          available: 8,
          used: 4,
        ),
        HrEmployeeLeaveBalance(
          leaveType: HrLeaveType.sick,
          available: 10,
          used: 2,
        ),
        HrEmployeeLeaveBalance(
          leaveType: HrLeaveType.earned,
          available: 15,
          used: 5,
        ),
      ],
      documents: const [
        HrEmployeeDocument(
          id: 'doc_1',
          title: 'Offer letter',
          uploadedOn: '2019-05-20',
          status: 'Verified',
        ),
        HrEmployeeDocument(
          id: 'doc_2',
          title: 'ID proof',
          uploadedOn: '2019-05-22',
          status: 'Verified',
        ),
      ],
      recentAttendance: _attendanceRecords
          .where((r) => r.employeeId == employeeId)
          .toList(growable: false),
      integrationNotes: [
        if (employee.teacherAppLinked == true)
          'Linked to Teacher app — ${employee.name} uses TA-01 attendance and TA-07 leave.',
        if (employee.department == HrDepartment.finance)
          'Payroll entries post to Finance module (FN-05 salary disbursement placeholder).',
        if (employee.department == HrDepartment.transport)
          'Also listed in Transport driver roster (TR-04 Ramesh Kumar).',
      ],
    );
  }

  @override
  Future<HrAttendanceData> getAttendance({required RepositoryQuery query}) async {
    return HrAttendanceData(
      records: List.unmodifiable(_attendanceRecords),
      attendanceTrend: const [
        HrTrendPoint(label: 'Mon', amountLakhs: 95.0, targetLakhs: 95.0),
        HrTrendPoint(label: 'Tue', amountLakhs: 96.5, targetLakhs: 95.0),
        HrTrendPoint(label: 'Wed', amountLakhs: 97.0, targetLakhs: 95.0),
        HrTrendPoint(label: 'Thu', amountLakhs: 96.0, targetLakhs: 95.0),
        HrTrendPoint(label: 'Fri', amountLakhs: 94.5, targetLakhs: 95.0),
      ],
      departmentBreakdown: const [
        HrSegment(label: 'Academics', value: 82, percent: 96),
        HrSegment(label: 'Transport', value: 12, percent: 92),
        HrSegment(label: 'Administration', value: 18, percent: 98),
        HrSegment(label: 'Finance', value: 8, percent: 97),
      ],
      summaryNote:
          'Geo + face verification enabled for teachers — aligns with Teacher app TA-01 attendance flow.',
    );
  }

  @override
  Future<HrLeaveData> getLeave({required RepositoryQuery query}) async {
    final requests = await _loadLeaveRequests();
    final pending = requests.where((r) => r.status == HrLeaveStatus.pending).length;
    return HrLeaveData(
      requests: requests,
      pendingCount: pending,
      leaveByType: const [
        HrSegment(label: 'Casual', value: 12, percent: 35),
        HrSegment(label: 'Sick', value: 8, percent: 24),
        HrSegment(label: 'Earned', value: 14, percent: 41),
      ],
      integrationNote:
          'Staff leave approvals sync with Teacher app TA-07 and Principal approval workflow.',
    );
  }

  Future<List<HrLeaveRequest>> _loadLeaveRequests() async {
    final store = MockHrWriteStore.instance;
    if (store.leaveRequests != null) {
      return List.from(store.leaveRequests!);
    }
    store.leaveRequests = List<HrLeaveRequest>.of([
        // Approved leave spanning the current demo window so the timetable
        // auto-cover is visible "today" without any manual marking.
        const HrLeaveRequest(
          id: 'lv_req_cover_demo',
          employeeId: 'HR-EMP-103',
          employeeName: 'Mr. Patel',
          department: HrDepartment.academics,
          leaveType: HrLeaveType.sick,
          fromDate: '2026-06-15',
          toDate: '2026-06-30',
          days: 12,
          status: HrLeaveStatus.approved,
          approver: 'Rajesh Iyer',
          reason: 'Medical leave',
        ),
        const HrLeaveRequest(
          id: 'lv_req_1',
          employeeId: 'HR-EMP-108',
          employeeName: 'Sunita Nair',
          department: HrDepartment.academics,
          leaveType: HrLeaveType.sick,
          fromDate: '2026-06-06',
          toDate: '2026-06-08',
          days: 3,
          status: HrLeaveStatus.pending,
          approver: 'Rajesh Iyer',
          reason: 'Medical leave',
        ),
        const HrLeaveRequest(
          id: 'lv_req_2',
          employeeId: 'HR-EMP-102',
          employeeName: 'Mrs. Rao',
          department: HrDepartment.academics,
          leaveType: HrLeaveType.casual,
          fromDate: '2026-06-10',
          toDate: '2026-06-10',
          days: 1,
          status: HrLeaveStatus.pending,
          approver: 'Rajesh Iyer',
          reason: 'Personal errand',
        ),
        const HrLeaveRequest(
          id: 'lv_req_3',
          employeeId: 'HR-EMP-101',
          employeeName: kMockTeacherName,
          department: HrDepartment.academics,
          leaveType: HrLeaveType.earned,
          fromDate: '2026-05-20',
          toDate: '2026-05-22',
          days: 3,
          status: HrLeaveStatus.approved,
          approver: 'Rajesh Iyer',
          reason: 'Family function',
        ),
        const HrLeaveRequest(
          id: 'lv_req_4',
          employeeId: 'HR-EMP-107',
          employeeName: 'Anil Verma',
          department: HrDepartment.finance,
          leaveType: HrLeaveType.earned,
          fromDate: '2026-06-12',
          toDate: '2026-06-13',
          days: 2,
          status: HrLeaveStatus.pending,
          approver: 'Kavitha Menon',
          reason: 'Travel',
        ),
        const HrLeaveRequest(
          id: 'lv_req_5',
          employeeId: 'HR-EMP-104',
          employeeName: 'Ramesh Kumar',
          department: HrDepartment.transport,
          leaveType: HrLeaveType.casual,
          fromDate: '2026-05-15',
          toDate: '2026-05-15',
          days: 1,
          status: HrLeaveStatus.approved,
          approver: 'Kavitha Menon',
          reason: 'Driver leave',
        ),
      ]);
    return List.from(store.leaveRequests!);
  }

  @override
  Future<HrLeaveRequest> createLeaveRequest({
    required RepositoryQuery query,
    required CreateHrLeaveRequest request,
  }) async {
    final store = MockHrWriteStore.instance;
    await _loadLeaveRequests();
    final id = store.nextLeaveId();
    final leave = HrLeaveRequest(
      id: id,
      employeeId: request.employeeId,
      employeeName: request.employeeName,
      department: request.department,
      leaveType: request.leaveType,
      fromDate: request.fromDate,
      toDate: request.toDate,
      days: request.days,
      status: HrLeaveStatus.pending,
      approver: request.approver,
      reason: request.reason,
    );
    store.leaveRequests!.insert(0, leave);
    return leave;
  }

  @override
  Future<HrLeaveRequest> approveLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    await _loadLeaveRequests();
    return _resolveLeaveRequest(
      leaveRequestId: leaveRequestId,
      status: HrLeaveStatus.approved,
      comment: request.comment,
    );
  }

  @override
  Future<HrLeaveRequest> rejectLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required ApproveLeaveRequest request,
  }) async {
    await _loadLeaveRequests();
    return _resolveLeaveRequest(
      leaveRequestId: leaveRequestId,
      status: HrLeaveStatus.rejected,
      comment: request.comment,
    );
  }

  HrLeaveRequest _resolveLeaveRequest({
    required String leaveRequestId,
    required HrLeaveStatus status,
    required String comment,
  }) {
    final store = MockHrWriteStore.instance;
    final requests = store.leaveRequests ?? const <HrLeaveRequest>[];
    final index = requests.indexWhere((r) => r.id == leaveRequestId);
    if (index < 0) {
      throw StateError('Leave request not found');
    }

    final current = requests[index];
    if (current.status != HrLeaveStatus.pending) {
      throw StateError('Leave request is already resolved');
    }
    final note = comment.trim();
    final nextReason = note.isEmpty
        ? current.reason
        : '${current.reason}\nManager note: $note';
    final updated = HrLeaveRequest(
      id: current.id,
      employeeId: current.employeeId,
      employeeName: current.employeeName,
      department: current.department,
      leaveType: current.leaveType,
      fromDate: current.fromDate,
      toDate: current.toDate,
      days: current.days,
      status: status,
      approver: current.approver,
      reason: nextReason,
    );
    requests[index] = updated;
    return updated;
  }

  @override
  Future<HrPayrollData> getPayroll({required RepositoryQuery query}) async {
    const base = HrPayrollData(
      runs: [
        HrPayrollRun(
          id: 'pay_run_1',
          period: 'May 2026',
          employeeCount: 148,
          grossAmount: '₹1.24 Cr',
          netAmount: '₹1.08 Cr',
          status: HrPayrollStatus.paid,
          processedOn: '2026-05-31',
        ),
        HrPayrollRun(
          id: 'pay_run_2',
          period: 'June 2026',
          employeeCount: 148,
          grossAmount: '₹1.24 Cr',
          netAmount: '₹1.08 Cr',
          status: HrPayrollStatus.draft,
          processedOn: '—',
        ),
      ],
      entries: [
        HrPayrollEntry(
          id: 'pay_1',
          employeeId: 'HR-EMP-101',
          employeeName: kMockTeacherName,
          department: HrDepartment.academics,
          basicPay: '₹45,000',
          allowances: '₹8,500',
          deductions: '₹4,200',
          netPay: '₹49,300',
          status: HrPayrollStatus.paid,
        ),
        HrPayrollEntry(
          id: 'pay_2',
          employeeId: 'HR-EMP-102',
          employeeName: 'Mrs. Rao',
          department: HrDepartment.academics,
          basicPay: '₹42,000',
          allowances: '₹7,800',
          deductions: '₹3,900',
          netPay: '₹45,900',
          status: HrPayrollStatus.paid,
        ),
        HrPayrollEntry(
          id: 'pay_3',
          employeeId: 'HR-EMP-104',
          employeeName: 'Ramesh Kumar',
          department: HrDepartment.transport,
          basicPay: '₹28,000',
          allowances: '₹4,500',
          deductions: '₹2,100',
          netPay: '₹30,400',
          status: HrPayrollStatus.paid,
        ),
        HrPayrollEntry(
          id: 'pay_4',
          employeeId: 'HR-EMP-107',
          employeeName: 'Anil Verma',
          department: HrDepartment.finance,
          basicPay: '₹38,000',
          allowances: '₹6,200',
          deductions: '₹3,500',
          netPay: '₹40,700',
          status: HrPayrollStatus.processed,
        ),
      ],
      salaryTrend: [
        HrTrendPoint(label: 'Jan', amountLakhs: 1.05, targetLakhs: 1.0),
        HrTrendPoint(label: 'Feb', amountLakhs: 1.06, targetLakhs: 1.0),
        HrTrendPoint(label: 'Mar', amountLakhs: 1.07, targetLakhs: 1.05),
        HrTrendPoint(label: 'Apr', amountLakhs: 1.08, targetLakhs: 1.05),
        HrTrendPoint(label: 'May', amountLakhs: 1.08, targetLakhs: 1.08),
      ],
      financeIntegrationNote:
          'Salary disbursement posts to Finance collections ledger (FN-05 placeholder). Review in Finance module before bank transfer.',
      financeRoute: RouteNames.financeCollections,
    );

    final store = MockHrWriteStore.instance;
    final runs = base.runs.map((run) {
      final override = store.payrollRunStatuses[run.id];
      if (override == null) return run;
      return HrPayrollRun(
        id: run.id,
        period: run.period,
        employeeCount: run.employeeCount,
        grossAmount: run.grossAmount,
        netAmount: run.netAmount,
        status: override,
        processedOn: override == HrPayrollStatus.processed
            ? (requestProcessedOn(store, run.id) ?? '2026-06-13')
            : run.processedOn,
      );
    }).toList();

    return HrPayrollData(
      runs: runs,
      entries: base.entries,
      salaryTrend: base.salaryTrend,
      financeIntegrationNote: base.financeIntegrationNote,
      financeRoute: base.financeRoute,
    );
  }

  static String? requestProcessedOn(MockHrWriteStore store, String runId) =>
      store.payrollProcessedOn[runId];

  @override
  Future<HrPayrollRun> processPayrollRun({
    required RepositoryQuery query,
    required ProcessHrPayrollRunRequest request,
  }) async {
    const draftRunId = 'pay_run_2';
    if (request.runId != draftRunId) {
      throw StateError('Payroll run not found or not processable');
    }
    final store = MockHrWriteStore.instance;
    final current = store.payrollRunStatuses[draftRunId];
    if (current == HrPayrollStatus.processed) {
      throw StateError('Payroll run already processed');
    }
    store.payrollRunStatuses[draftRunId] = HrPayrollStatus.processed;
    store.payrollProcessedOn[draftRunId] =
        request.processedOn ?? '2026-06-13';
    final data = await getPayroll(query: query);
    return data.runs.firstWhere((r) => r.id == draftRunId);
  }

  Future<List<HrEmployee>> _loadEmployees() async {
    final store = MockHrWriteStore.instance;
    store.employees ??= List<HrEmployee>.from(_employees);
    return store.employees!;
  }

  @override
  Future<HrEmployee> createEmployee({
    required RepositoryQuery query,
    required CreateHrEmployeeRequest request,
  }) async {
    final employees = await _loadEmployees();
    if (employees.any((e) => e.employeeCode == request.employeeCode)) {
      throw StateError('Employee code already exists');
    }

    final employee = HrEmployee(
      id: MockHrWriteStore.instance.nextEmployeeId(),
      name: request.name,
      employeeCode: request.employeeCode,
      department: request.department,
      role: request.role,
      designation: request.designation,
      email: request.email,
      phone: request.phone,
      joinDate: request.joinDate,
      status: HrEmployeeStatus.probation,
    );
    employees.insert(0, employee);
    return employee;
  }

  @override
  Future<HrEmployee> updateEmployee({
    required RepositoryQuery query,
    required UpdateHrEmployeeRequest request,
  }) async {
    final employees = await _loadEmployees();
    final index = employees.indexWhere((e) => e.id == request.employeeId);
    if (index < 0) {
      throw StateError('Employee not found');
    }

    final current = employees[index];
    final updated = HrEmployee(
      id: current.id,
      name: request.name,
      employeeCode: current.employeeCode,
      department: request.department,
      role: current.role,
      designation: request.designation,
      email: current.email,
      phone: request.phone,
      joinDate: current.joinDate,
      status: current.status,
      teacherAppLinked: current.teacherAppLinked,
      classLabel: current.classLabel,
    );
    employees[index] = updated;
    return updated;
  }

  @override
  Future<HrEmployee> setEmployeeStatus({
    required RepositoryQuery query,
    required SetHrEmployeeStatusRequest request,
  }) async {
    if (request.status != HrEmployeeStatus.active &&
        request.status != HrEmployeeStatus.inactive) {
      throw StateError('Only active or inactive status supported');
    }

    final employees = await _loadEmployees();
    final index = employees.indexWhere((e) => e.id == request.employeeId);
    if (index < 0) {
      throw StateError('Employee not found');
    }

    final current = employees[index];
    final updated = HrEmployee(
      id: current.id,
      name: current.name,
      employeeCode: current.employeeCode,
      department: current.department,
      role: current.role,
      designation: current.designation,
      email: current.email,
      phone: current.phone,
      joinDate: current.joinDate,
      status: request.status,
      teacherAppLinked: current.teacherAppLinked,
      classLabel: current.classLabel,
    );
    employees[index] = updated;
    return updated;
  }

  @override
  Future<HrRecruitmentData> getRecruitment({required RepositoryQuery query}) async {
    return const HrRecruitmentData(
      candidates: [
        HrCandidate(
          id: 'cand_1',
          name: 'Deepa Krishnan',
          role: 'Physics Teacher',
          department: HrDepartment.academics,
          appliedOn: '2026-05-28',
          stage: HrRecruitmentStage.interview,
          experience: '6 years',
          source: 'Referral',
        ),
        HrCandidate(
          id: 'cand_2',
          name: 'Vikram Singh',
          role: 'Lab Assistant',
          department: HrDepartment.academics,
          appliedOn: '2026-06-01',
          stage: HrRecruitmentStage.screening,
          experience: '2 years',
          source: 'Job portal',
        ),
        HrCandidate(
          id: 'cand_3',
          name: 'Meera Joshi',
          role: 'Counselor',
          department: HrDepartment.administration,
          appliedOn: '2026-05-20',
          stage: HrRecruitmentStage.selected,
          experience: '4 years',
          source: 'Campus drive',
        ),
        HrCandidate(
          id: 'cand_4',
          name: 'Arun Das',
          role: 'Bus Driver',
          department: HrDepartment.transport,
          appliedOn: '2026-06-03',
          stage: HrRecruitmentStage.applied,
          experience: '8 years',
          source: 'Walk-in',
        ),
        HrCandidate(
          id: 'cand_5',
          name: 'Lakshmi Reddy',
          role: 'Accounts Assistant',
          department: HrDepartment.finance,
          appliedOn: '2026-04-15',
          stage: HrRecruitmentStage.joined,
          experience: '3 years',
          source: 'Referral',
        ),
      ],
      openPositions: 4,
      pipelineCounts: [
        HrSegment(label: 'Applied', value: 8, percent: 32),
        HrSegment(label: 'Screening', value: 5, percent: 20),
        HrSegment(label: 'Interview', value: 4, percent: 16),
        HrSegment(label: 'Selected', value: 3, percent: 12),
        HrSegment(label: 'Joined', value: 5, percent: 20),
      ],
      hiringTrend: [
        HrTrendPoint(label: 'Q1', amountLakhs: 3, targetLakhs: 4),
        HrTrendPoint(label: 'Q2', amountLakhs: 5, targetLakhs: 4),
      ],
    );
  }

  @override
  Future<HrPerformanceData> getPerformance({required RepositoryQuery query}) async {
    return const HrPerformanceData(
      reviews: [
        HrPerformanceReview(
          id: 'rev_1',
          employeeId: 'HR-EMP-101',
          employeeName: kMockTeacherName,
          department: HrDepartment.academics,
          cycle: HrReviewCycle.q2,
          rating: '4.6 / 5',
          status: HrReviewStatus.inProgress,
          reviewer: 'Rajesh Iyer',
          dueDate: '2026-06-30',
        ),
        HrPerformanceReview(
          id: 'rev_2',
          employeeId: 'HR-EMP-102',
          employeeName: 'Mrs. Rao',
          department: HrDepartment.academics,
          cycle: HrReviewCycle.q2,
          rating: '4.2 / 5',
          status: HrReviewStatus.completed,
          reviewer: 'Rajesh Iyer',
          dueDate: '2026-06-15',
        ),
        HrPerformanceReview(
          id: 'rev_3',
          employeeId: 'HR-EMP-103',
          employeeName: 'Mr. Patel',
          department: HrDepartment.academics,
          cycle: HrReviewCycle.q2,
          rating: '—',
          status: HrReviewStatus.overdue,
          reviewer: 'Rajesh Iyer',
          dueDate: '2026-06-01',
        ),
        HrPerformanceReview(
          id: 'rev_4',
          employeeId: 'HR-EMP-105',
          employeeName: 'Kavitha Menon',
          department: HrDepartment.hr,
          cycle: HrReviewCycle.annual,
          rating: '4.8 / 5',
          status: HrReviewStatus.completed,
          reviewer: 'Rajesh Iyer',
          dueDate: '2026-05-31',
        ),
      ],
      ratingDistribution: [
        HrSegment(label: 'Outstanding (4.5+)', value: 28, percent: 35),
        HrSegment(label: 'Meets (3.5–4.4)', value: 42, percent: 52),
        HrSegment(label: 'Needs improvement', value: 10, percent: 13),
      ],
      completionTrend: [
        HrTrendPoint(label: 'Q1', amountLakhs: 88, targetLakhs: 90),
        HrTrendPoint(label: 'Q2', amountLakhs: 72, targetLakhs: 90),
      ],
      managementInsight:
          'Teacher performance scores feed Management MG-06 school performance dashboard.',
    );
  }

  @override
  Future<HrSettingsData> getSettings({required RepositoryQuery query}) async {
    return const HrSettingsData(
      defaultDepartment: HrDepartment.academics,
      sections: [
        HrSettingsSection(
          id: 'attendance',
          title: 'Attendance & verification',
          items: [
            HrSettingItem(
              id: 'geo_fence',
              label: 'Geo-fence radius',
              value: '200 m',
              description: 'Staff check-in boundary around campus',
              editable: true,
            ),
            HrSettingItem(
              id: 'face_verify',
              label: 'Face verification',
              value: 'Enabled for teachers',
              description: 'Syncs with Teacher app TA-01 attendance',
              editable: true,
            ),
          ],
        ),
        HrSettingsSection(
          id: 'leave',
          title: 'Leave policy',
          items: [
            HrSettingItem(
              id: 'casual_days',
              label: 'Casual leave quota',
              value: '12 days / year',
              description: 'Applies to teaching and non-teaching staff',
              editable: true,
            ),
            HrSettingItem(
              id: 'principal_approval',
              label: 'Principal approval',
              value: 'Required > 3 days',
              description: 'Long leave routes to Principal workflow',
              editable: false,
            ),
          ],
        ),
        HrSettingsSection(
          id: 'payroll',
          title: 'Payroll & Finance',
          items: [
            HrSettingItem(
              id: 'pay_cycle',
              label: 'Pay cycle',
              value: 'Monthly (last working day)',
              description: 'Posts to Finance FN-05 salary ledger placeholder',
              editable: true,
            ),
            HrSettingItem(
              id: 'bank_file',
              label: 'Bank transfer file',
              value: 'HDFC NEFT batch',
              description: 'Export after Finance approval',
              editable: false,
            ),
          ],
        ),
        HrSettingsSection(
          id: 'integrations',
          title: 'Module integrations',
          items: [
            HrSettingItem(
              id: 'teacher_sync',
              label: 'Teacher app sync',
              value: 'Enabled',
              description:
                  'Priya Sharma, Mrs. Rao, Mr. Patel linked to Teacher profiles',
              editable: true,
            ),
            HrSettingItem(
              id: 'mgmt_kpi',
              label: 'Management KPI feed',
              value: 'Active',
              description: 'Attendance and performance metrics to MG-01 / MG-06',
              editable: false,
            ),
          ],
        ),
      ],
    );
  }

  // --- HR reporting / export reads (HR-1/2/4/5/6/7) -------------------------
  // Derived from the same mock employees / payroll / leave data so the offline
  // path renders a representative report and mock↔API parity holds.

  /// Parses a formatted rupee string (e.g. "₹45,000") into a number.
  static num _rupees(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return num.tryParse(digits) ?? 0;
  }

  @override
  Future<HrSalaryRegister> getSalaryRegister({
    required RepositoryQuery query,
    required String runId,
  }) async {
    final payroll = await getPayroll(query: query);
    final rows = [
      for (final e in payroll.entries)
        HrSalaryRegisterRow(
          employeeId: e.employeeId,
          code: e.employeeId,
          name: e.employeeName,
          dept: e.department.name,
          basicPay: _rupees(e.basicPay),
          allowances: _rupees(e.allowances),
          deductions: _rupees(e.deductions),
          netPay: _rupees(e.netPay),
        ),
    ];
    final totals = rows.fold<List<num>>(
      [0, 0, 0, 0],
      (acc, r) => [
        acc[0] + r.basicPay,
        acc[1] + r.allowances,
        acc[2] + r.deductions,
        acc[3] + r.netPay,
      ],
    );
    final run = payroll.runs.where((r) => r.id == runId);
    return HrSalaryRegister(
      runId: runId,
      period: run.isEmpty ? '' : run.first.period,
      rows: rows,
      totals: HrSalaryRegisterTotals(
        basicPay: totals[0],
        allowances: totals[1],
        deductions: totals[2],
        netPay: totals[3],
      ),
    );
  }

  @override
  Future<HrPayslipBundle> getPayslips({
    required RepositoryQuery query,
    required String runId,
  }) async {
    final register = await getSalaryRegister(query: query, runId: runId);
    return HrPayslipBundle(
      runId: register.runId,
      period: register.period,
      payslips: [
        for (final r in register.rows)
          HrPayslip(
            employeeId: r.employeeId,
            code: r.code,
            name: r.name,
            dept: r.dept,
            earnings: [
              HrPayslipLine(label: 'Basic pay', amount: r.basicPay),
              HrPayslipLine(label: 'Allowances', amount: r.allowances),
            ],
            deductionLines: [
              HrPayslipLine(label: 'Deductions', amount: r.deductions),
            ],
            grossEarnings: r.basicPay + r.allowances,
            totalDeductions: r.deductions,
            netPay: r.netPay,
          ),
      ],
    );
  }

  @override
  Future<HrAttendanceMuster> getAttendanceMuster({
    required RepositoryQuery query,
    required String month,
  }) async {
    // Representative single-day sample from the mock attendance records, expanded
    // to a full-month grid so the muster view renders without a live ledger.
    final parts = month.split('-');
    final year = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 2026;
    final mon = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 6;
    final days = DateTime(year, mon + 1, 0).day;
    final employees = await _loadEmployees();

    HrMusterStatus statusFor(HrAttendanceStatus? s) => switch (s) {
          HrAttendanceStatus.present => HrMusterStatus.present,
          HrAttendanceStatus.late => HrMusterStatus.late_,
          _ => HrMusterStatus.absent,
        };

    final rows = <HrMusterRow>[];
    for (final emp in employees) {
      final record = _attendanceRecords
          .where((r) => r.employeeId == emp.id)
          .cast<HrAttendanceRecord?>()
          .firstWhere((r) => true, orElse: () => null);
      final dayStatus = statusFor(record?.status);
      final daily = <HrMusterStatus>[];
      var present = 0;
      for (var d = 1; d <= days; d++) {
        // Weekends (Sat/Sun) non-working, otherwise the sampled status.
        final weekday = DateTime(year, mon, d).weekday;
        if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
          daily.add(HrMusterStatus.nonWorking);
        } else {
          daily.add(dayStatus);
          if (dayStatus == HrMusterStatus.present ||
              dayStatus == HrMusterStatus.late_) {
            present++;
          }
        }
      }
      final working = daily.where((s) => s != HrMusterStatus.nonWorking).length;
      rows.add(HrMusterRow(
        employeeId: emp.id,
        code: emp.employeeCode,
        name: emp.name,
        dept: emp.department.name,
        dailyStatus: daily,
        presentCount: present,
        percent: working > 0 ? ((present / working) * 100).round() : 0,
      ));
    }

    return HrAttendanceMuster(
      month: month,
      daysInMonth: days,
      lateAfter: '09:15',
      holidayDays: const [],
      rows: rows,
    );
  }

  @override
  Future<HrLeaveBalanceReport> getLeaveBalances({
    required RepositoryQuery query,
  }) async {
    const policy = [
      ('casual', 12),
      ('sick', 12),
      ('earned', 15),
    ];
    final employees = await _loadEmployees();
    final requests = await _loadLeaveRequests();
    String typeName(HrLeaveType t) => switch (t) {
          HrLeaveType.casual => 'casual',
          HrLeaveType.sick => 'sick',
          HrLeaveType.earned => 'earned',
          _ => 'casual',
        };
    return HrLeaveBalanceReport(
      leaveTypes: [for (final p in policy) p.$1],
      rows: [
        for (final emp in employees)
          HrLeaveBalanceRow(
            employeeId: emp.id,
            code: emp.employeeCode,
            name: emp.name,
            dept: emp.department.name,
            balances: [
              for (final p in policy)
                () {
                  final used = requests
                      .where((r) =>
                          r.employeeId == emp.id &&
                          r.status == HrLeaveStatus.approved &&
                          typeName(r.leaveType) == p.$1)
                      .fold<num>(0, (sum, r) => sum + r.days);
                  return HrLeaveBalanceCell(
                    leaveType: p.$1,
                    available: p.$2,
                    used: used,
                    remaining: (p.$2 - used) < 0 ? 0 : (p.$2 - used),
                  );
                }(),
            ],
          ),
      ],
    );
  }

  @override
  Future<HrHeadcountReport> getHeadcount({required RepositoryQuery query}) async {
    final employees = await _loadEmployees();
    final counts = <String, int>{};
    var total = 0;
    for (final e in employees) {
      if (e.status != HrEmployeeStatus.active) continue;
      counts.update(e.department.name, (v) => v + 1, ifAbsent: () => 1);
      total++;
    }
    final rows = counts.entries
        .map((e) => HrHeadcountRow(department: e.key, count: e.value))
        .toList()
      ..sort((a, b) =>
          b.count.compareTo(a.count) == 0
              ? a.department.compareTo(b.department)
              : b.count.compareTo(a.count));
    return HrHeadcountReport(rows: rows, total: total);
  }

  @override
  Future<HrEmployeeDirectory> getEmployeeDirectory({
    required RepositoryQuery query,
  }) async {
    final employees = await _loadEmployees();
    return HrEmployeeDirectory(
      rows: [
        for (final e in employees)
          HrDirectoryRow(
            employeeId: e.id,
            code: e.employeeCode,
            name: e.name,
            dept: e.department.name,
            designation: e.designation,
            phone: e.phone,
            joinDate: e.joinDate,
            status: e.status.name,
          ),
      ],
    );
  }
}
