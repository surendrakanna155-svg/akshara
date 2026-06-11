import '../../../features/employee/employee_models.dart';
import '../repository_query.dart';

abstract class EmployeeRepository {
  Future<EmployeeDashboard> getDashboard({required RepositoryQuery query});

  Future<List<EmployeeSummary>> listEmployees({
    required RepositoryQuery query,
    String? search,
  });

  Future<EmployeeDetail> getEmployee({
    required RepositoryQuery query,
    required String employeeId,
  });

  Future<EmployeeRoleAssignment> assignRole({
    required RepositoryQuery query,
    required String employeeId,
    required String roleCode,
    bool isPrimary = false,
  });
}
