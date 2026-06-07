import 'package:akshara_erp/features/library/library_models.dart';
import 'package:akshara_erp/features/library/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createProviderTestContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('Library providers', () {
    test('libraryDashboardProvider returns dashboard data', () async {      await container.read(libraryDashboardFutureProvider.future);

      final data = container.read(libraryDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.recentIssues, isNotEmpty);
    });

    test('libraryDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          libraryDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(libraryDashboardProvider), isNull);
    });

    test('libraryCatalogProvider returns catalog', () async {      await container.read(libraryCatalogFutureProvider.future);

      final books = container.read(libraryCatalogProvider);

      expect(books, isNotNull);
      expect(books!, hasLength(6));
    });

    test('libraryFilteredCatalogProvider filters available books', () async {
      container = createProviderTestContainer(
        overrides: [
          libraryCatalogFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(libraryFilteredCatalogProvider);
      expect(
        filtered.every((b) => b.status == LibraryBookStatus.available),
        isTrue,
      );
    });

    test('libraryIssuesProvider returns issue records', () async {      await container.read(libraryIssuesFutureProvider.future);

      final issues = container.read(libraryIssuesProvider);

      expect(issues, isNotNull);
      expect(issues!, hasLength(4));
    });

    test('libraryFilteredIssuesProvider filters overdue', () async {
      container = createProviderTestContainer(
        overrides: [
          libraryIssuesFilterProvider.overrideWith((ref) => 2),
        ],
      );

      final filtered = container.read(libraryFilteredIssuesProvider);
      expect(
        filtered.every((i) => i.status == LibraryLoanStatus.overdue),
        isTrue,
      );
    });

    test('libraryReturnsProvider returns return records', () async {      await container.read(libraryReturnsFutureProvider.future);

      final returns = container.read(libraryReturnsProvider);

      expect(returns, isNotNull);
      expect(returns!, hasLength(4));
    });

    test('libraryMembersProvider returns SIS-linked members', () async {      await container.read(libraryMembersFutureProvider.future);

      final members = container.read(libraryMembersProvider);

      expect(members, isNotNull);
      expect(
        members!.where((m) => m.sisStudentId != null),
        isNotEmpty,
      );
    });

    test('libraryFinesProvider returns fines data', () async {      await container.read(libraryFinesFutureProvider.future);

      final data = container.read(libraryFinesProvider);

      expect(data, isNotNull);
      expect(data!.fines, hasLength(4));
      expect(data.totalPending, isNotEmpty);
    });

    test('libraryResourcesProvider returns digital resources', () async {      await container.read(libraryResourcesFutureProvider.future);

      final data = container.read(libraryResourcesProvider);

      expect(data, isNotNull);
      expect(data!.resources, hasLength(5));
      expect(data.studentAppRoute, isNotEmpty);
    });

    test('libraryReportsProvider returns reports data', () async {      await container.read(libraryReportsFutureProvider.future);

      final data = container.read(libraryReportsProvider);

      expect(data, isNotNull);
      expect(data!.catalog, hasLength(6));
    });
  });
}
