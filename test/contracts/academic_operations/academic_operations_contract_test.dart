import 'package:akshara_erp/core/repositories/interfaces/academic_operations_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_academic_operations_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Academic operations contract', () {
    late MockAcademicOperationsRepository repository;

    setUp(() {
      repository = MockAcademicOperationsRepository();
    });

    test('implements repository contract', () {
      expect(repository, isA<AcademicOperationsRepository>());
    });

    test('suggestClassMappings returns deterministic mappings', () async {
      final first = await repository.suggestClassMappings(
        query: _query,
        sourceYearId: '2026–27',
        targetYearId: '2027–28',
      );
      final second = await repository.suggestClassMappings(
        query: _query,
        sourceYearId: '2026–27',
        targetYearId: '2027–28',
      );
      expect(first.length, greaterThan(0));
      expect(first.first.targetClassLabel, second.first.targetClassLabel);
    });

    test('preview and execute year transition updates students', () async {
      final mappings = await repository.suggestClassMappings(
        query: _query,
        sourceYearId: '2026–27',
        targetYearId: '2027–28',
      );
      final preview = await repository.previewYearTransition(
        query: _query,
        sourceYearId: '2026–27',
        targetYearId: '2027–28',
        mappings: mappings,
      );
      expect(preview.previewRows, isNotEmpty);

      final report = await repository.executeYearTransition(
        query: _query,
        jobId: preview.id,
      );
      expect(report.executedCount, greaterThan(0));

      final job = await repository.getTransitionJob(query: _query, jobId: preview.id);
      expect(job.status.name, anyOf('executed', 'failed'));
    });
  });
}
