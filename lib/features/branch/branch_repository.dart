import '../../core/repositories/repository_query.dart';
import 'branch_models.dart';

abstract class BranchRepository {
  Future<BranchDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<List<BranchAssignment>> listAssignments({
    required RepositoryQuery query,
    required String branchId,
  });

  Future<BranchAssignment> assignSchool({
    required RepositoryQuery query,
    required String branchId,
    required String schoolId,
    required String schoolName,
    required String managerName,
  });
}

class MockBranchRepository implements BranchRepository {
  final Map<String, List<BranchAssignment>> _assignmentsByBranch = {
    'BR-01': [
      const BranchAssignment(
        id: 'BA-001',
        branchId: 'BR-01',
        schoolId: 'SCH-1001',
        schoolName: 'Akshara International Hyderabad',
        assignedManager: 'Asha Menon',
      ),
    ],
    'BR-02': [
      const BranchAssignment(
        id: 'BA-101',
        branchId: 'BR-02',
        schoolId: 'SCH-2003',
        schoolName: 'Sunrise Academy Bengaluru',
        assignedManager: 'Rahul Pai',
      ),
    ],
  };

  @override
  Future<BranchDashboard> getDashboard({
    required RepositoryQuery query,
  }) async {
    const branches = [
      Branch(
        id: 'BR-01',
        name: 'South Metro Branch',
        region: 'South',
        schoolCount: 6,
        activeStudentCount: 14250,
        revenueLakhs: 224.4,
        status: 'healthy',
      ),
      Branch(
        id: 'BR-02',
        name: 'West Growth Branch',
        region: 'West',
        schoolCount: 4,
        activeStudentCount: 9780,
        revenueLakhs: 161.3,
        status: 'watchlist',
      ),
    ];
    return const BranchDashboard(
      totalBranches: 2,
      totalSchools: 10,
      totalRevenueLakhs: 385.7,
      branches: branches,
    );
  }

  @override
  Future<List<BranchAssignment>> listAssignments({
    required RepositoryQuery query,
    required String branchId,
  }) async {
    return List<BranchAssignment>.unmodifiable(
      _assignmentsByBranch[branchId] ?? const [],
    );
  }

  @override
  Future<BranchAssignment> assignSchool({
    required RepositoryQuery query,
    required String branchId,
    required String schoolId,
    required String schoolName,
    required String managerName,
  }) async {
    final assignment = BranchAssignment(
      id: 'BA-${DateTime.now().millisecondsSinceEpoch}',
      branchId: branchId,
      schoolId: schoolId,
      schoolName: schoolName,
      assignedManager: managerName,
    );
    final current = List<BranchAssignment>.from(
      _assignmentsByBranch[branchId] ?? const [],
    )..add(assignment);
    _assignmentsByBranch[branchId] = current;
    return assignment;
  }
}
