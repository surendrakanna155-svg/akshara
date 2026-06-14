import 'hr_models.dart';

class CreateHrLeaveRequest {
  const CreateHrLeaveRequest({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    this.approver = 'HR Manager',
  });

  final String employeeId;
  final String employeeName;
  final HrDepartment department;
  final HrLeaveType leaveType;
  final String fromDate;
  final String toDate;
  final int days;
  final String reason;
  final String approver;
}

class ProcessHrPayrollRunRequest {
  const ProcessHrPayrollRunRequest({
    required this.runId,
    this.processedOn,
  });

  final String runId;
  final String? processedOn;
}
