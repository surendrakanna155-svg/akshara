import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/mock/mock_onboarding_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';

void main() {
  test('previewStudentImport validates required fields', () async {
    final repo = MockOnboardingRepository();
    const query = RepositoryQuery(
      tenantId: 'org',
      organizationId: 'org',
      schoolId: 'school',
    );
    final result = await repo.previewStudentImport(
      query: query,
      fileName: 'students.csv',
      rows: const [
        {'studentName': 'A', 'admissionNumber': 'ADM-1'},
        {},
      ],
    );
    expect(result.job.validRows, 1);
    expect(result.job.invalidRows, 1);
  });
}
