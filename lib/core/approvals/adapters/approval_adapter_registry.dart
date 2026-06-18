import '../../repositories/repository_query.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import 'approval_type_adapter.dart';
import 'attendance_correction_approval_adapter.dart';
import 'exam_results_approval_adapter.dart';
import 'finance_approval_adapters.dart';
import 'inventory_po_approval_adapter.dart';
import 'staff_leave_approval_adapter.dart';
import 'student_leave_approval_adapter.dart';

/// Dispatches post-decision hooks to module adapters (M-D3–M-D6).
class ApprovalAdapterRegistry {
  const ApprovalAdapterRegistry._();

  static ApprovalTypeAdapter? adapterFor(ApprovalRequestType type) =>
      switch (type) {
        ApprovalRequestType.examResults => ExamResultsApprovalAdapter(),
        ApprovalRequestType.studentLeave => StudentLeaveApprovalAdapter(),
        ApprovalRequestType.staffLeave => StaffLeaveApprovalAdapter(),
        ApprovalRequestType.attendanceCorrection =>
          AttendanceCorrectionApprovalAdapter(),
        ApprovalRequestType.feeStructure => FeeStructureApprovalAdapter(),
        ApprovalRequestType.feeConcession => FeeConcessionApprovalAdapter(),
        ApprovalRequestType.refund => RefundApprovalAdapter(),
        ApprovalRequestType.inventoryPo => InventoryPoApprovalAdapter(),
        _ => null,
      };

  static void dispatchApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
    bool skipDomainEffects = false,
  }) {
    if (skipDomainEffects) return;
    adapterFor(request.type)?.onApproved(query: query, request: request);
  }

  static void dispatchRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
    bool skipDomainEffects = false,
  }) {
    if (skipDomainEffects) return;
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
