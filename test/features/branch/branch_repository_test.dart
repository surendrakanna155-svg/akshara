import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/branch/branch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch repository dashboard and assignment flow', () async {
    final repo = MockBranchRepository();
    final dashboard = await repo.getDashboard(query: RepositoryQuery.demo);
    expect(dashboard.branches, isNotEmpty);

    final created = await repo.assignSchool(
      query: RepositoryQuery.demo,
      branchId: 'BR-01',
      schoolId: 'SCH-NEW-01',
      schoolName: 'New Horizon Campus',
      managerName: 'Ishita Rao',
    );
    final assignments = await repo.listAssignments(
      query: RepositoryQuery.demo,
      branchId: 'BR-01',
    );
    expect(assignments.any((row) => row.id == created.id), isTrue);
  });
}
