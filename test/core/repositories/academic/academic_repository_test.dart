import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/academic/academic_repository.dart';
import 'package:akshara_erp/core/repositories/academic/api/academic_remote_data_source.dart';
import 'package:akshara_erp/core/repositories/academic/api/api_academic_repository.dart';
import 'package:akshara_erp/core/repositories/academic/hybrid_academic_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_academic_repository.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicRepository', () {
    const query = RepositoryQuery.demo;

    test('mock repository returns legacy catalog options', () async {
      final repo = MockAcademicRepository();

      final years = await repo.getYears(query: query);
      final classes = await repo.getClasses(query: query);
      final sections = await repo.getSections(query: query);
      final teachers = await repo.getTeacherAssignments(query: query);

      expect(
        years.items.map((item) => item.yearLabel),
        anyOf(contains('2026–27'), contains('2026-27')),
      );
      expect(classes.items.map((item) => item.className), contains('10'));
      expect(sections.items.map((item) => item.sectionName), contains('A'));
      expect(
        teachers.items.map((item) => item.teacherName),
        contains('Staging Teacher A'),
      );
    });

    test('mock repository filters sections by classId', () async {
      final repo = MockAcademicRepository();
      final classes = await repo.getClasses(query: query);
      final classFive = classes.items.firstWhere((item) => item.className == '5');

      final sections = await repo.getSections(
        query: query,
        classId: classFive.classId,
      );

      expect(sections.items, isNotEmpty);
      expect(
        sections.items.every((item) => item.classId == classFive.classId),
        isTrue,
      );
    });

    test('providers wire mock when API flags are disabled', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: false),
          ),
        ],
      );

      expect(
        container.read(academicRepositoryProvider),
        isA<MockAcademicRepository>(),
      );
      container.dispose();
    });

    test('providers wire hybrid when API flags are enabled', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          academicApiEnabledProvider.overrideWith((ref) => true),
        ],
      );

      expect(
        container.read(academicRepositoryProvider),
        isA<HybridAcademicRepository>(),
      );
      container.dispose();
    });

    test('hybrid repository implements AcademicRepository', () {
      expect(
        HybridAcademicRepository(
          api: ApiAcademicRepository(
            remote: AcademicRemoteDataSource(Dio()),
          ),
        ),
        isA<AcademicRepository>(),
      );
    });
  });
}
