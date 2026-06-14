import '../../../../features/hr/hr_models.dart';

/// Mutable HR write state for mock repositories.
class MockHrWriteStore {
  MockHrWriteStore._();

  static final MockHrWriteStore instance = MockHrWriteStore._();

  List<HrLeaveRequest>? leaveRequests;
  final Map<String, HrPayrollStatus> payrollRunStatuses = {};
  final Map<String, String> payrollProcessedOn = {};
  int _leaveSeq = 200;

  void reset() {
    leaveRequests = null;
    payrollRunStatuses.clear();
    payrollProcessedOn.clear();
    _leaveSeq = 200;
  }

  String nextLeaveId() {
    _leaveSeq++;
    return 'lv_req_$_leaveSeq';
  }
}
