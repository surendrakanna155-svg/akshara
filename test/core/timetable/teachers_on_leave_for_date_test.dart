import 'package:akshara_erp/core/timetable/mock_daily_timetable_store.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:flutter_test/flutter_test.dart';

HrLeaveRequest leave({
  required String id,
  required String employeeId,
  required String from,
  required String to,
  required HrLeaveStatus status,
}) =>
    HrLeaveRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeId,
      department: HrDepartment.academics,
      leaveType: HrLeaveType.sick,
      fromDate: from,
      toDate: to,
      days: 1,
      status: status,
      approver: 'Principal',
      reason: 'x',
    );

void main() {
  final requests = [
    leave(id: 'a', employeeId: 'HR-EMP-103', from: '2026-06-18', to: '2026-06-20', status: HrLeaveStatus.approved),
    leave(id: 'b', employeeId: 'HR-EMP-102', from: '2026-06-19', to: '2026-06-19', status: HrLeaveStatus.pending),
    leave(id: 'c', employeeId: 'HR-EMP-101', from: '2026-06-01', to: '2026-06-02', status: HrLeaveStatus.approved),
  ];

  test('only approved leave covering the date counts', () {
    final onLeave = teachersOnLeaveForDate(requests, DateTime(2026, 6, 19));
    // 'a' approved and covers 19th; 'b' pending (ignored); 'c' approved but past.
    expect(onLeave, {'HR-EMP-103'});
  });

  test('a date with no approved leave returns empty', () {
    final onLeave = teachersOnLeaveForDate(requests, DateTime(2026, 6, 25));
    expect(onLeave, isEmpty);
  });

  test('inclusive of the leave end date', () {
    final onLeave = teachersOnLeaveForDate(requests, DateTime(2026, 6, 20));
    expect(onLeave.contains('HR-EMP-103'), isTrue);
  });
}
