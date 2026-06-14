import 'package:akshara_erp/core/repositories/interfaces/continuity_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_communication_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_continuity_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Continuity repository contract', () {
    late MockContinuityRepository repository;

    setUp(() {
      repository = MockContinuityRepository(
        teacherRepository: MockTeacherRepository(),
        communicationRepository: MockCommunicationRepository(),
        timetableRepository: MockTimetableRepository(),
        parentRepository: MockParentRepository(),
      );
    });

    test('implements continuity contract', () {
      expect(repository, isA<ContinuityRepository>());
    });

    test('preview and execute continuity migration', () async {
      final plan = await repository.previewContinuityMigration(
        query: _query,
        studentId: 'SIS-STU-10418',
        fromClass: '7',
        fromSection: 'A',
        toClass: '8',
        toSection: 'A',
        academicYear: '2026-27',
      );
      expect(plan.teacherImpact.threadCount, greaterThanOrEqualTo(0));

      final result = await repository.executeContinuityMigration(
        query: _query,
        planId: plan.id,
      );
      expect(result.status.name, 'executed');
      expect(result.auditTrail, isNotEmpty);
    });
  });
}
