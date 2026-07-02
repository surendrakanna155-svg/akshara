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
    this.onBehalf = false,
    this.halfDay = false,
    this.override = false,
  });

  final String employeeId;
  final String employeeName;
  final HrDepartment department;
  final HrLeaveType leaveType;
  final String fromDate;
  final String toDate;

  /// Whole days requested. Fractional half-day is expressed via [halfDay] (which
  /// the backend records as 0.5) so this stays an int for the common whole-day path.
  final int days;
  final String reason;
  final String approver;

  /// HR-D3 — a manager filing this leave FOR the employee (records `createdBy`).
  final bool onBehalf;

  /// HR-D3 — a half-day request (0.5 day) rather than whole days.
  final bool halfDay;

  /// HR-D3 — allow the request even though it exceeds the employee's balance
  /// (the backend refuses over-balance requests with 409 unless this is set).
  final bool override;
}

class ApproveLeaveRequest {
  const ApproveLeaveRequest({this.comment = ''});

  final String comment;
}

/// HR-3 — approve or reject many leave requests at once.
class BatchDecideHrLeaveRequest {
  const BatchDecideHrLeaveRequest({
    required this.ids,
    required this.approve,
    this.reason = '',
  });

  final List<String> ids;
  final bool approve;
  final String reason;
}

/// HR-D2 — confirm an employee off probation, or extend it to a new end date.
class SetHrEmployeeProbationRequest {
  const SetHrEmployeeProbationRequest.confirm({required this.employeeId})
      : extend = false,
        probationEndDate = null;

  const SetHrEmployeeProbationRequest.extend({
    required this.employeeId,
    required String this.probationEndDate,
  }) : extend = true;

  final String employeeId;

  /// true → extend (with [probationEndDate]); false → confirm (clear probation).
  final bool extend;
  final String? probationEndDate;

  String get action => extend ? 'extend' : 'confirm';
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
