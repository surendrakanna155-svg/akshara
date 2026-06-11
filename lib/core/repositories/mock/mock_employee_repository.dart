import '../../../features/employee/employee_models.dart';
import '../interfaces/employee_repository.dart';
import '../repository_query.dart';

class MockEmployeeRepository implements EmployeeRepository {
  final _employees = [
    const EmployeeSummary(
      id: 'emp_1',
      employeeCode: 'EMP-TEACH-01',
      displayName: 'Meera Iyer',
      email: 'meera@school.demo',
      phone: '+919999000001',
      status: 'active',
      primaryDepartment: 'Academics',
      userId: 'user_teacher_1',
    ),
    const EmployeeSummary(
      id: 'emp_2',
      employeeCode: 'EMP-PRIN-01',
      displayName: 'Ravi Kumar',
      status: 'active',
      primaryDepartment: 'Leadership',
      userId: 'user_principal_1',
    ),
  ];

  @override
  Future<EmployeeDashboard> getDashboard({required RepositoryQuery query}) async {
    return EmployeeDashboard(
      totalEmployees: _employees.length,
      activeEmployees: _employees.length,
      roleDistribution: const [
        {'roleCode': 'teacher', 'count': 1},
        {'roleCode': 'principal', 'count': 1},
      ],
      workloadIndex: 42,
      recentAssignments: const [
        {
          'employeeId': 'emp_1',
          'employeeName': 'Meera Iyer',
          'roleCode': 'teacher',
          'effectiveFrom': '2025-04-01',
        },
      ],
    );
  }

  @override
  Future<List<EmployeeSummary>> listEmployees({
    required RepositoryQuery query,
    String? search,
  }) async {
    if (search == null || search.isEmpty) return _employees;
    return _employees
        .where((e) => e.displayName.toLowerCase().contains(search.toLowerCase()))
        .toList();
  }

  @override
  Future<EmployeeDetail> getEmployee({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    final summary = _employees.firstWhere((e) => e.id == employeeId);
    return EmployeeDetail(
      summary: summary,
      roles: const [
        EmployeeRoleAssignment(
          id: 'role_1',
          roleCode: 'teacher',
          effectiveFrom: '2025-04-01',
          isPrimary: true,
        ),
        EmployeeRoleAssignment(
          id: 'role_2',
          roleCode: 'classTeacher',
          effectiveFrom: '2025-06-01',
          isPrimary: false,
        ),
      ],
    );
  }

  @override
  Future<EmployeeRoleAssignment> assignRole({
    required RepositoryQuery query,
    required String employeeId,
    required String roleCode,
    bool isPrimary = false,
  }) async {
    return EmployeeRoleAssignment(
      id: 'role_new',
      roleCode: roleCode,
      effectiveFrom: '2026-06-10',
      isPrimary: isPrimary,
    );
  }
}
