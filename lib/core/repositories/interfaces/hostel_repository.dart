import '../../../features/hostel/hostel_models.dart';
import '../repository_query.dart';

/// Contract for hostel data access (mock or API).
abstract class HostelRepository {
  Future<HostelDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<HostelStudent>> getStudents({required RepositoryQuery query});
  Future<List<HostelRoom>> getRooms({required RepositoryQuery query});
  Future<List<HostelAttendanceRecord>> getAttendanceRecords({required RepositoryQuery query});
  Future<List<HostelLeaveRequest>> getLeaveRequests({required RepositoryQuery query});
  Future<HostelMessData> getMessData({required RepositoryQuery query});
  Future<HostelVisitorsData> getVisitors({required RepositoryQuery query});
  Future<HostelReportsData> getReports({required RepositoryQuery query});
  Future<HostelOccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query});
}
