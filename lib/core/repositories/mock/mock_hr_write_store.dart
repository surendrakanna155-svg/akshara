import '../../../../features/hr/hr_models.dart';

/// Mutable HR write state for mock repositories.
class MockHrWriteStore {
  MockHrWriteStore._();

  static final MockHrWriteStore instance = MockHrWriteStore._();

  List<HrLeaveRequest>? leaveRequests;
  List<HrEmployee>? employees;
  final Map<String, HrPayrollStatus> payrollRunStatuses = {};
  final Map<String, String> payrollProcessedOn = {};
  int _leaveSeq = 200;
  int _employeeSeq = 200;

  void reset() {
    leaveRequests = null;
    employees = null;
    payrollRunStatuses.clear();
    payrollProcessedOn.clear();
    _leaveSeq = 200;
    _employeeSeq = 200;
  }

  String nextLeaveId() {
    _leaveSeq++;
    return 'lv_req_$_leaveSeq';
  }

  String nextEmployeeId() {
    _employeeSeq++;
    return 'HR-EMP-$_employeeSeq';
  }
}
