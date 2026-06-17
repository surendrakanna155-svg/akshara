import '../../approvals/approval_models.dart';
import '../../approvals/approval_request_type.dart';
import '../../approvals/approval_requests.dart';
import '../repository_query.dart';
import 'mock_approval_repository.dart';

/// Demo approval queue for Principal Approval Center (mock mode only).
Future<void> seedMockApprovalDemoIfEmpty({
  required MockApprovalRepository repository,
  required RepositoryQuery query,
}) async {
  final pending = await repository.listPending(query: query);
  if (pending.isNotEmpty) return;

  final seeds = <SubmitApprovalRequest>[
    const SubmitApprovalRequest(
      type: ApprovalRequestType.budget,
      title: 'Science lab upgrade — Q3 budget',
      summary: 'Capital expenditure for lab equipment refresh',
      requesterId: 'finance_mgr',
      requesterName: 'Finance Manager',
      entityType: 'budget_request',
      entityId: 'budget_lab_q3',
      payload: {'amount': '₹8.5L'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.examResults,
      title: 'Publish Class 8-A Mathematics results',
      summary: 'Half-yearly exam — 32 students',
      requesterId: 'teacher_001',
      requesterName: 'Priya Sharma',
      entityType: 'exam_session',
      entityId: 'exam_math_8a',
      payload: {'classLabel': '8-A', 'subject': 'Mathematics'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.attendanceCorrection,
      title: 'Class 6-B attendance correction — 12 Jun',
      summary: 'Bus delay — 4 students marked absent incorrectly',
      requesterId: 'teacher_002',
      requesterName: 'Anil Kumar',
      entityType: 'attendance_day',
      entityId: 'att_6b_2026_06_12',
      payload: {'classLabel': '6-B', 'date': '12 Jun 2026'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.studentLeave,
      title: 'Rahul Mehta — 3-day medical leave',
      summary: 'Parent submitted leave for Class 9-A',
      requesterId: 'parent_101',
      requesterName: 'Sunita Mehta',
      entityType: 'student_leave',
      entityId: 'leave_stu_101',
      payload: {'classLabel': '9-A', 'days': 3},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.staffLeave,
      title: 'Neha Singh — casual leave (2 days)',
      summary: 'Mathematics teacher — family function',
      requesterId: 'staff_045',
      requesterName: 'Neha Singh',
      entityType: 'staff_leave',
      entityId: 'leave_staff_045',
      payload: {'department': 'Academics'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.expense,
      title: 'Marketing campaign — Summer Open Day',
      summary: 'Admissions outreach spend',
      requesterId: 'adm_head',
      requesterName: 'Admissions Head',
      entityType: 'expense_request',
      entityId: 'exp_marketing_summer',
      payload: {'amount': '₹2.2L'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.payroll,
      title: 'June 2026 payroll batch',
      summary: 'Monthly payroll disbursement',
      requesterId: 'finance_mgr',
      requesterName: 'Finance Manager',
      entityType: 'payroll_batch',
      entityId: 'payroll_2026_06',
      payload: {'amount': '₹42.0L'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.vendor,
      title: 'Smart board vendor — Phase 2',
      summary: 'IT procurement — classroom displays',
      requesterId: 'it_admin',
      requesterName: 'IT Admin',
      entityType: 'vendor_payment',
      entityId: 'vendor_smartboard_p2',
      payload: {'amount': '₹6.8L'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.admission,
      title: 'Ananya Reddy — Class 5 admission',
      summary: 'Documents verified — awaiting principal sign-off',
      requesterId: 'counselor_01',
      requesterName: 'Meera N.',
      entityType: 'admission_application',
      entityId: 'adm_ananya_reddy',
      payload: {'classLabel': '5'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.inventoryPo,
      title: 'Science lab consumables PO',
      summary: 'Storekeeper raised PO — chemicals and glassware',
      requesterId: 'storekeeper_01',
      requesterName: 'Rajesh P.',
      entityType: 'procurement_order',
      entityId: 'po_lab_consumables',
      payload: {'amount': '₹1.2L'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.feeConcession,
      title: 'Sibling discount — Kapoor twins',
      summary: '10% concession on tuition — verified siblings',
      requesterId: 'finance_mgr',
      requesterName: 'Finance Manager',
      entityType: 'fee_concession',
      entityId: 'concession_kapoor',
      payload: {'amount': '₹18K/yr'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.marketing,
      title: 'Digital ads — Q3 enrollment',
      summary: 'Approved campaign spend (historical)',
      requesterId: 'marketing_lead',
      requesterName: 'Marketing Lead',
      entityType: 'marketing_campaign',
      entityId: 'mkt_q3_ads',
      payload: {'amount': '₹1.5L'},
    ),
    const SubmitApprovalRequest(
      type: ApprovalRequestType.expense,
      title: 'Sports day logistics',
      summary: 'Rejected — over threshold without quotes',
      requesterId: 'activities_head',
      requesterName: 'Activities Head',
      entityType: 'expense_request',
      entityId: 'exp_sports_day',
      payload: {'amount': '₹85K'},
    ),
  ];

  for (final seed in seeds) {
    await repository.submit(query: query, request: seed);
  }

  // Mark historical items as decided for filter demos.
  final all = await repository.listByFilter(
    query: query,
    filter: const ApprovalListFilter(),
  );
  for (final item in all) {
    if (item.title.startsWith('Digital ads')) {
      await repository.approve(
        query: query,
        request: ApproveApprovalRequest(
          approvalId: item.id,
          actorId: 'principal_001',
          actorName: 'Dr. Rao',
          comment: 'Within enrollment budget.',
        ),
      );
    } else if (item.title.startsWith('Sports day')) {
      await repository.reject(
        query: query,
        request: RejectApprovalRequest(
          approvalId: item.id,
          actorId: 'principal_001',
          actorName: 'Dr. Rao',
          comment: 'Obtain three vendor quotes before resubmitting.',
        ),
      );
    }
  }
}
