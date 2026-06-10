import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/academic/academic_catalog_provider.dart';
import 'package:akshara_erp/core/repositories/academic/academic_models.dart';
import 'package:akshara_erp/core/repositories/academic/academic_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_academic_repository.dart';
import 'package:akshara_erp/core/repositories/paginated_result.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

class _CountingAcademicRepository extends MockAcademicRepository {
  int catalogLoadCount = 0;

  @override
  Future<PaginatedResult<AcademicYear>> getYears({
    required RepositoryQuery query,
  }) async {
    catalogLoadCount++;
    return super.getYears(query: query);
  }
}

class _EmptyAcademicRepository implements AcademicRepository {
  @override
  Future<PaginatedResult<AcademicYear>> getYears({
    required RepositoryQuery query,
  }) async =>
      const PaginatedResult(
        items: [],
        page: 1,
        pageSize: 100,
        total: 0,
        hasMore: false,
      );

  @override
  Future<PaginatedResult<AcademicClass>> getClasses({
    required RepositoryQuery query,
    String? academicYearId,
  }) async =>
      const PaginatedResult(
        items: [],
        page: 1,
        pageSize: 100,
        total: 0,
        hasMore: false,
      );

  @override
  Future<PaginatedResult<AcademicSection>> getSections({
    required RepositoryQuery query,
    String? classId,
    String? academicYearId,
  }) async =>
      const PaginatedResult(
        items: [],
        page: 1,
        pageSize: 100,
        total: 0,
        hasMore: false,
      );

  @override
  Future<PaginatedResult<AcademicTeacherAssignment>> getTeacherAssignments({
    required RepositoryQuery query,
    String? classId,
    String? sectionId,
  }) async =>
      const PaginatedResult(
        items: [],
        page: 1,
        pageSize: 100,
        total: 0,
        hasMore: false,
      );
}

void main() {
  group('Academic catalog hardening', () {
    test('year options normalize en-dash mock labels to hyphen', () async {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          academicRepositoryProvider.overrideWith(
            (ref) => MockAcademicRepository(),
          ),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(academicCatalogFutureProvider.future);

      expect(container.read(yearOptionsProvider), contains('2026-27'));
      expect(container.read(yearOptionsProvider), isNot(contains('2026–27')));
    });

    test('academicCatalogFutureProvider caches a single catalog load', () async {
      final repo = _CountingAcademicRepository();
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          academicRepositoryProvider.overrideWith((ref) => repo),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(academicCatalogFutureProvider.future);
      await container.read(academicCatalogFutureProvider.future);
      container.read(yearOptionsProvider);

      expect(repo.catalogLoadCount, 1);
    });

    test('empty catalog returns safe empty option lists', () async {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          academicRepositoryProvider.overrideWith(
            (ref) => _EmptyAcademicRepository(),
          ),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(academicCatalogFutureProvider.future);

      expect(container.read(yearOptionsProvider), isEmpty);
      expect(container.read(classOptionsProvider), isEmpty);
      expect(container.read(sectionOptionsProvider), isEmpty);
      expect(container.read(defaultAcademicYearLabelProvider), '2026-27');
    });

    test('inactive catalog rows are excluded from dropdown options', () async {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          academicRepositoryProvider.overrideWith((ref) => _FilteredStatusRepo()),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(academicCatalogFutureProvider.future);

      expect(container.read(classOptionsProvider), ['5']);
      expect(container.read(classOptionsProvider), isNot(contains('99')));
    });

    test('registry filter index clamps when catalog is empty', () {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          academicRepositoryProvider.overrideWith(
            (ref) => _EmptyAcademicRepository(),
          ),
          sisRegistryFilterProvider.overrideWith((ref) => 10),
        ]),
      );
      addTearDown(container.dispose);

      expect(container.read(sisRegistryFilterLabelsProvider), [
        'All',
        'Active',
        'Prospect',
      ]);
      expect(container.read(sisRegistryEffectiveFilterIndexProvider), 2);
    });

    test('mock mode wires MockAcademicRepository only', () {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: false),
          ),
        ]),
      );
      addTearDown(container.dispose);

      expect(
        container.read(academicRepositoryProvider),
        isA<MockAcademicRepository>(),
      );
    });
  });
}

class _FilteredStatusRepo extends MockAcademicRepository {
  @override
  Future<PaginatedResult<AcademicClass>> getClasses({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    return const PaginatedResult(
      items: [
        AcademicClass(
          classId: 'active-class',
          academicYearId: 'year-1',
          className: '5',
          displayOrder: 5,
          status: 'active',
        ),
        AcademicClass(
          classId: 'archived-class',
          academicYearId: 'year-1',
          className: '99',
          displayOrder: 99,
          status: 'archived',
        ),
      ],
      page: 1,
      pageSize: 100,
      total: 2,
      hasMore: false,
    );
  }
}
