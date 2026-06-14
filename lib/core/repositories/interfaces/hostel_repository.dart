import '../../../features/hostel/hostel_models.dart';
import '../../../features/hostel/hostel_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for hostel data access (mock or API).
abstract class HostelRepository {
  Future<HostelDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<HostelStudent>> getStudents({required RepositoryQuery query});
  Future<PaginatedResult<HostelRoom>> getRooms({required RepositoryQuery query});
  Future<PaginatedResult<HostelAttendanceRecord>> getAttendanceRecords({required RepositoryQuery query});
  Future<PaginatedResult<HostelLeaveRequest>> getLeaveRequests({required RepositoryQuery query});
  Future<HostelMessData> getMessData({required RepositoryQuery query});
  Future<HostelVisitorsData> getVisitors({required RepositoryQuery query});
  Future<HostelReportsData> getReports({required RepositoryQuery query});
  Future<HostelOccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query});
  Future<HostelStudent> admitHostelStudent({
    required RepositoryQuery query,
    required AdmitHostelStudentRequest request,
  });
  Future<HostelStudent> assignHostelRoom({
    required RepositoryQuery query,
    required AssignHostelRoomRequest request,
  });
  Future<HostelStudent> checkoutHostelStudent({
    required RepositoryQuery query,
    required CheckoutHostelStudentRequest request,
  });
}
