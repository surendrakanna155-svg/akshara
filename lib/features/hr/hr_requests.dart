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

class CreateHrEmployeeRequest {
  const CreateHrEmployeeRequest({
    required this.name,
    required this.employeeCode,
    required this.department,
    required this.role,
    required this.designation,
    required this.email,
    required this.phone,
    this.joinDate = '13 Jun 2026',
  });

  final String name;
  final String employeeCode;
  final HrDepartment department;
  final HrEmployeeRole role;
  final String designation;
  final String email;
  final String phone;
  final String joinDate;
}

class UpdateHrEmployeeRequest {
  const UpdateHrEmployeeRequest({
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.phone,
    required this.department,
  });

  final String employeeId;
  final String name;
  final String designation;
  final String phone;
  final HrDepartment department;
}

class SetHrEmployeeStatusRequest {
  const SetHrEmployeeStatusRequest({
    required this.employeeId,
    required this.status,
  });

  final String employeeId;
  final HrEmployeeStatus status;
}
