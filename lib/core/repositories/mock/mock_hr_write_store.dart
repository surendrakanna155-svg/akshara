import '../../../../features/hr/hr_models.dart';

/// Mutable HR write state for mock repositories.
class MockHrWriteStore {
  MockHrWriteStore._();

  static final MockHrWriteStore instance = MockHrWriteStore._();

  List<HrLeaveRequest>? leaveRequests;
  List<HrEmployee>? employees;
  final Map<String, HrPayrollStatus> payrollRunStatuses = {};
  final Map<String, String> payrollProcessedOn = {};

  /// MOD-2 — per-employee salary structures, keyed by employeeId.
  final Map<String, HrSalaryStructure> salaryStructures = {};

  /// MOD-2 — draft runs generated from structures (+ their entries), keyed by
  /// run id. Surfaced by getPayroll alongside the seeded demo runs.
  final Map<String, HrPayrollRun> generatedRuns = {};
  final Map<String, List<HrPayrollEntry>> generatedEntries = {};

  /// HR-D2 — per-employee probation end dates (yyyy-mm-dd). Absent = not on
  /// probation. Lazily seeded by the mock repo so the probation report + the
  /// confirm/extend action have representative data offline.
  Map<String, String>? probationEndDates;

  /// HR-D1 — per-employee documents (with optional expiry). Lazily seeded by the
  /// mock repo. Keyed by employee id.
  Map<String, List<HrEmployeeDocument>>? employeeDocuments;

  int _leaveSeq = 200;
  int _employeeSeq = 200;

  void reset() {
    leaveRequests = null;
    employees = null;
    probationEndDates = null;
    employeeDocuments = null;
    payrollRunStatuses.clear();
    payrollProcessedOn.clear();
    salaryStructures.clear();
    generatedRuns.clear();
    generatedEntries.clear();
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
