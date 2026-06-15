import '../../../../features/employee/employee_models.dart';
import '../../../../features/homework_intelligence/homework_intelligence_models.dart';
import '../../../../features/inventory_distribution/inventory_distribution_models.dart';
import '../../../../features/student_360/student_360_models.dart';
import '../../../../features/phase5/phase5_models.dart';
import '../../interfaces/employee_repository.dart';
import '../../interfaces/homework_intelligence_repository.dart';
import '../../interfaces/inventory_distribution_repository.dart';
import '../../interfaces/student_360_repository.dart';
import '../../repository_query.dart';
import 'phase4_mapper.dart';
import 'phase4_remote_datasource.dart';
import '../phase5/phase5_mapper.dart';

class ApiHomeworkIntelligenceRepository implements HomeworkIntelligenceRepository {
  ApiHomeworkIntelligenceRepository({required Phase4RemoteDataSource remote}) : _remote = remote;
  final Phase4RemoteDataSource _remote;

  @override
  Future<HomeworkIntelligencePlan> getPlan({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
    String? sectionName,
  }) async {
    final data = await _remote.fetchHomeworkIntelligencePlan(
      query: query,
      className: className,
      subjectName: subjectName,
      examType: examType,
    );
    return Phase4Mapper.homeworkPlanFromApi(data);
  }

  @override
  Future<({String runId, HomeworkIntelligencePlan plan, int? homeworkCount})> generate({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
    bool apply = false,
  }) async {
    final data = await _remote.generateHomeworkIntelligence(
      query: query,
      body: {
        'className': className,
        'subjectName': subjectName,
        'examType': examType,
        'apply': apply,
      },
    );
    final applied = data['applied'] as Map?;
    return (
      runId: data['runId'] as String? ?? '',
      plan: Phase4Mapper.homeworkPlanFromApi(data),
      homeworkCount: applied?['homeworkIds'] is List ? (applied!['homeworkIds'] as List).length : null,
    );
  }
}

class ApiStudent360Repository implements Student360Repository {
  ApiStudent360Repository({required Phase4RemoteDataSource remote}) : _remote = remote;
  final Phase4RemoteDataSource _remote;

  @override
  Future<Student360Profile> getProfile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final data = await _remote.fetchStudent360Profile(query: query, studentId: studentId);
    return Phase4Mapper.student360FromApi(data);
  }

  @override
  Future<List<StudentTimelineEvent>> getTimeline({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final rows = await _remote.fetchStudentTimeline(query: query, studentId: studentId);
    return rows.map(Phase4Mapper.timelineFromApi).toList();
  }
}

class ApiEmployeeRepository implements EmployeeRepository {
  ApiEmployeeRepository({required Phase4RemoteDataSource remote}) : _remote = remote;
  final Phase4RemoteDataSource _remote;

  @override
  Future<EmployeeDashboard> getDashboard({required RepositoryQuery query}) async {
    return Phase4Mapper.employeeDashboardFromApi(
      await _remote.fetchEmployeeDashboard(query: query),
    );
  }

  @override
  Future<List<EmployeeSummary>> listEmployees({
    required RepositoryQuery query,
    String? search,
  }) async {
    final rows = await _remote.fetchEmployees(query: query, search: search);
    return rows.map(Phase4Mapper.employeeSummaryFromApi).toList();
  }

  @override
  Future<EmployeeDetail> getEmployee({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    return Phase4Mapper.employeeDetailFromApi(
      await _remote.fetchEmployee(query: query, employeeId: employeeId),
    );
  }

  @override
  Future<EmployeeRoleAssignment> assignRole({
    required RepositoryQuery query,
    required String employeeId,
    required String roleCode,
    bool isPrimary = false,
  }) async {
    return Phase4Mapper.employeeRoleFromApi(
      await _remote.assignEmployeeRole(
        query: query,
        employeeId: employeeId,
        roleCode: roleCode,
        isPrimary: isPrimary,
      ),
    );
  }
}

class ApiInventoryDistributionRepository implements InventoryDistributionRepository {
  ApiInventoryDistributionRepository({required Phase4RemoteDataSource remote}) : _remote = remote;
  final Phase4RemoteDataSource _remote;

  @override
  Future<InvDistributionDashboard> getDashboard({required RepositoryQuery query}) async {
    return Phase4Mapper.distributionDashboardFromApi(
      await _remote.fetchDistributionDashboard(query: query),
    );
  }

  @override
  Future<List<InvCatalogItem>> listCatalog({
    required RepositoryQuery query,
    String? category,
  }) async {
    final rows = await _remote.fetchDistributionCatalog(query: query, category: category);
    return rows.map(Phase4Mapper.catalogItemFromApi).toList();
  }

  @override
  Future<List<InvStudentDistribution>> listDistributions({
    required RepositoryQuery query,
    String? studentId,
    String? status,
  }) async {
    final rows = await _remote.fetchDistributions(
      query: query,
      studentId: studentId,
      status: status,
    );
    return rows.map(Phase4Mapper.distributionFromApi).toList();
  }

  @override
  Future<InvStudentDistribution> createDistribution({
    required RepositoryQuery query,
    required String studentId,
    required String catalogItemId,
    int quantity = 1,
  }) async {
    return Phase4Mapper.distributionFromApi(
      await _remote.createDistribution(
        query: query,
        studentId: studentId,
        catalogItemId: catalogItemId,
        quantity: quantity,
      ),
    );
  }

  @override
  Future<InvStudentDistribution> transitionStatus({
    required RepositoryQuery query,
    required String distributionId,
    required String status,
    String? notes,
  }) async {
    return Phase4Mapper.distributionFromApi(
      await _remote.transitionDistribution(
        query: query,
        distributionId: distributionId,
        status: status,
        notes: notes,
      ),
    );
  }

  @override
  Future<({InvStudentDistribution distribution, String? paymentRequestId})> requestReplacement({
    required RepositoryQuery query,
    required String distributionId,
    String? notes,
  }) async {
    final data = await _remote.requestReplacement(
      query: query,
      distributionId: distributionId,
      notes: notes,
    );
    return (
      distribution: Phase4Mapper.distributionFromApi(
        Map<String, dynamic>.from(data['distribution'] as Map? ?? data),
      ),
      paymentRequestId: data['paymentRequestId'] as String?,
    );
  }

  @override
  Future<InvDistributionReports> getReports({required RepositoryQuery query}) async {
    return Phase5Mapper().mapDistributionReports(
      await _remote.fetchDistributionReports(query: query),
    );
  }

  @override
  Future<List<InvReplacementRequest>> listReplacementRequests({
    required RepositoryQuery query,
    String? status,
  }) async {
    final rows = await _remote.fetchReplacementRequests(query: query, status: status);
    return rows.map(Phase4Mapper.replacementRequestFromApi).toList();
  }

  @override
  Future<InvReplacementRequest> approveReplacement({
    required RepositoryQuery query,
    required String requestId,
  }) async {
    return Phase4Mapper.replacementRequestFromApi(
      await _remote.approveReplacement(query: query, requestId: requestId),
    );
  }

  @override
  Future<InvReplacementRequest> fulfillReplacement({
    required RepositoryQuery query,
    required String requestId,
  }) async {
    return Phase4Mapper.replacementRequestFromApi(
      await _remote.fulfillReplacement(query: query, requestId: requestId),
    );
  }

  @override
  Future<InvReplacementRequest> rejectReplacement({
    required RepositoryQuery query,
    required String requestId,
    String? reason,
  }) async {
    return Phase4Mapper.replacementRequestFromApi(
      await _remote.rejectReplacement(
        query: query,
        requestId: requestId,
        reason: reason,
      ),
    );
  }
}
