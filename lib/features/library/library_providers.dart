import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';

import '../../core/repositories/repository_query.dart';
import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/async/erp_async_state.dart';
import 'library_models.dart';

// LB-01 Dashboard
final libraryDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final libraryDashboardErrorProvider = StateProvider<bool>((ref) => false);
final libraryDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final libraryDashboardFilterProvider = StateProvider<int>((ref) => 0);

final libraryDashboardFutureProvider = FutureProvider<LibraryDashboardData>((ref) async {
return await ref.read(libraryRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final libraryDashboardProvider = Provider<LibraryDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryDashboardFutureProvider),
    manualLoading: ref.watch(libraryDashboardLoadingProvider), manualError: ref.watch(libraryDashboardErrorProvider), manualEmpty: ref.watch(libraryDashboardEmptyProvider),
  );
});

final libraryDashboardViewStateProvider =
    Provider<ErpViewState<LibraryDashboardData>>((ref) {
  return resolveErpAsync(
    ref.watch(libraryDashboardFutureProvider),
    forceLoading: ref.watch(libraryDashboardLoadingProvider),
    forceError: ref.watch(libraryDashboardErrorProvider),
    forceEmpty: ref.watch(libraryDashboardEmptyProvider),
  );
});

// LB-02 Catalog
final libraryCatalogLoadingProvider = StateProvider<bool>((ref) => false);
final libraryCatalogErrorProvider = StateProvider<bool>((ref) => false);
final libraryCatalogEmptyProvider = StateProvider<bool>((ref) => false);
final libraryCatalogFilterProvider = StateProvider<int>((ref) => 0);
final libraryCatalogPageProvider = StateProvider<int>((ref) => 1);

final libraryCatalogQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(libraryCatalogPageProvider);
  return baseQuery.withPage(page);
});

final libraryCatalogFutureProvider = FutureProvider<PaginatedResult<LibraryBook>>((ref) async {
return ref.read(libraryRepositoryProvider).getCatalog(query: ref.watch(libraryCatalogQueryProvider));
});

final libraryCatalogPageResultProvider = Provider<PaginatedResult<LibraryBook>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryCatalogFutureProvider),
    manualLoading: ref.watch(libraryCatalogLoadingProvider), manualError: ref.watch(libraryCatalogErrorProvider), manualEmpty: ref.watch(libraryCatalogEmptyProvider),
  );
});

final libraryCatalogProvider = Provider<List<LibraryBook>?>((ref) {
  return ref.watch(libraryCatalogPageResultProvider)?.items ?? const [];
});

final libraryFilteredCatalogProvider = Provider<List<LibraryBook>>((ref) {
  final books = ref.watch(libraryCatalogProvider);
  if (books == null) return const [];
  final filterIndex = ref.watch(libraryCatalogFilterProvider);
  return switch (filterIndex) {
    1 => books
        .where((b) => b.status == LibraryBookStatus.available)
        .toList(),
    2 => books
        .where((b) => b.status == LibraryBookStatus.issued)
        .toList(),
    3 => books
        .where((b) => b.category == 'Textbook')
        .toList(),
    _ => books,
  };
});

// LB-03 Issues
final libraryIssuesLoadingProvider = StateProvider<bool>((ref) => false);
final libraryIssuesErrorProvider = StateProvider<bool>((ref) => false);
final libraryIssuesEmptyProvider = StateProvider<bool>((ref) => false);
final libraryIssuesFilterProvider = StateProvider<int>((ref) => 0);
final libraryIssuesPageProvider = StateProvider<int>((ref) => 1);

final libraryIssuesQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(libraryIssuesPageProvider);
  return baseQuery.withPage(page);
});

final libraryIssuesFutureProvider = FutureProvider<PaginatedResult<LibraryIssueRecord>>((ref) async {
return ref.read(libraryRepositoryProvider).getIssues(query: ref.watch(libraryIssuesQueryProvider));
});

final libraryIssuesPageResultProvider = Provider<PaginatedResult<LibraryIssueRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryIssuesFutureProvider),
    manualLoading: ref.watch(libraryIssuesLoadingProvider), manualError: ref.watch(libraryIssuesErrorProvider), manualEmpty: ref.watch(libraryIssuesEmptyProvider),
  );
});

final libraryIssuesProvider = Provider<List<LibraryIssueRecord>?>((ref) {
  return ref.watch(libraryIssuesPageResultProvider)?.items ?? const [];
});

final libraryFilteredIssuesProvider = Provider<List<LibraryIssueRecord>>(
  (ref) {
    final issues = ref.watch(libraryIssuesProvider);
    if (issues == null) return const [];
    final filterIndex = ref.watch(libraryIssuesFilterProvider);
    return switch (filterIndex) {
      1 => issues
          .where((i) => i.status == LibraryLoanStatus.active)
          .toList(),
      2 => issues
          .where((i) => i.status == LibraryLoanStatus.overdue)
          .toList(),
      3 => issues
          .where((i) => i.memberType == LibraryMemberType.student)
          .toList(),
      _ => issues,
    };
  },
);

// LB-04 Returns
final libraryReturnsLoadingProvider = StateProvider<bool>((ref) => false);
final libraryReturnsErrorProvider = StateProvider<bool>((ref) => false);
final libraryReturnsEmptyProvider = StateProvider<bool>((ref) => false);
final libraryReturnsFilterProvider = StateProvider<int>((ref) => 0);
final libraryReturnsPageProvider = StateProvider<int>((ref) => 1);

final libraryReturnsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(libraryReturnsPageProvider);
  return baseQuery.withPage(page);
});

final libraryReturnsFutureProvider = FutureProvider<PaginatedResult<LibraryReturnRecord>>((ref) async {
return ref.read(libraryRepositoryProvider).getReturns(query: ref.watch(libraryReturnsQueryProvider));
});

final libraryReturnsPageResultProvider = Provider<PaginatedResult<LibraryReturnRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryReturnsFutureProvider),
    manualLoading: ref.watch(libraryReturnsLoadingProvider), manualError: ref.watch(libraryReturnsErrorProvider), manualEmpty: ref.watch(libraryReturnsEmptyProvider),
  );
});

final libraryReturnsProvider = Provider<List<LibraryReturnRecord>?>((ref) {
  return ref.watch(libraryReturnsPageResultProvider)?.items ?? const [];
});

final libraryFilteredReturnsProvider = Provider<List<LibraryReturnRecord>>(
  (ref) {
    final returns = ref.watch(libraryReturnsProvider);
    if (returns == null) return const [];
    final filterIndex = ref.watch(libraryReturnsFilterProvider);
    return switch (filterIndex) {
      1 => returns
          .where((r) => r.fineAmount != '₹0')
          .toList(),
      2 => returns
          .where((r) => r.condition == LibraryReturnCondition.damaged)
          .toList(),
      _ => returns,
    };
  },
);

// LB-05 Members
final libraryMembersLoadingProvider = StateProvider<bool>((ref) => false);
final libraryMembersErrorProvider = StateProvider<bool>((ref) => false);
final libraryMembersEmptyProvider = StateProvider<bool>((ref) => false);
final libraryMembersFilterProvider = StateProvider<int>((ref) => 0);
final libraryMembersPageProvider = StateProvider<int>((ref) => 1);

final libraryMembersQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(libraryMembersPageProvider);
  return baseQuery.withPage(page);
});

final libraryMembersFutureProvider = FutureProvider<PaginatedResult<LibraryMember>>((ref) async {
return ref.read(libraryRepositoryProvider).getMembers(query: ref.watch(libraryMembersQueryProvider));
});

final libraryMembersPageResultProvider = Provider<PaginatedResult<LibraryMember>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryMembersFutureProvider),
    manualLoading: ref.watch(libraryMembersLoadingProvider), manualError: ref.watch(libraryMembersErrorProvider), manualEmpty: ref.watch(libraryMembersEmptyProvider),
  );
});

final libraryMembersProvider = Provider<List<LibraryMember>?>((ref) {
  return ref.watch(libraryMembersPageResultProvider)?.items ?? const [];
});

final libraryFilteredMembersProvider = Provider<List<LibraryMember>>((ref) {
  final members = ref.watch(libraryMembersProvider);
  if (members == null) return const [];
  final filterIndex = ref.watch(libraryMembersFilterProvider);
  return switch (filterIndex) {
    1 => members
        .where((m) => m.memberType == LibraryMemberType.student)
        .toList(),
    2 => members
        .where((m) => m.memberType == LibraryMemberType.teacher)
        .toList(),
    3 => members
        .where((m) => m.status == LibraryMemberStatus.blocked)
        .toList(),
    _ => members,
  };
});

// LB-06 Fines
final libraryFinesLoadingProvider = StateProvider<bool>((ref) => false);
final libraryFinesErrorProvider = StateProvider<bool>((ref) => false);
final libraryFinesEmptyProvider = StateProvider<bool>((ref) => false);
final libraryFinesFilterProvider = StateProvider<int>((ref) => 0);

final libraryFinesFutureProvider = FutureProvider<LibraryFinesData>((ref) async {
return await ref.read(libraryRepositoryProvider).getFines(query: ref.watch(repositoryQueryProvider));
});

final libraryFinesProvider = Provider<LibraryFinesData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryFinesFutureProvider),
    manualLoading: ref.watch(libraryFinesLoadingProvider), manualError: ref.watch(libraryFinesErrorProvider), manualEmpty: ref.watch(libraryFinesEmptyProvider),
  );
});

final libraryFilteredFinesProvider = Provider<List<LibraryFine>>((ref) {
  final data = ref.watch(libraryFinesProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(libraryFinesFilterProvider);
  return switch (filterIndex) {
    1 => data.fines
        .where((f) => f.status == LibraryFineStatus.pending)
        .toList(),
    2 => data.fines
        .where((f) => f.status == LibraryFineStatus.paid)
        .toList(),
    3 => data.fines
        .where((f) => f.financeLinked)
        .toList(),
    _ => data.fines,
  };
});

// LB-07 Digital Resources
final libraryResourcesLoadingProvider = StateProvider<bool>((ref) => false);
final libraryResourcesErrorProvider = StateProvider<bool>((ref) => false);
final libraryResourcesEmptyProvider = StateProvider<bool>((ref) => false);
final libraryResourcesFilterProvider = StateProvider<int>((ref) => 0);

final libraryResourcesFutureProvider = FutureProvider<LibraryDigitalResourcesData>((ref) async {
return await ref.read(libraryRepositoryProvider).getDigitalResources(query: ref.watch(repositoryQueryProvider));
});

final libraryResourcesProvider = Provider<LibraryDigitalResourcesData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryResourcesFutureProvider),
    manualLoading: ref.watch(libraryResourcesLoadingProvider), manualError: ref.watch(libraryResourcesErrorProvider), manualEmpty: ref.watch(libraryResourcesEmptyProvider),
  );
});

// LB-08 Reports
final libraryReportsLoadingProvider = StateProvider<bool>((ref) => false);
final libraryReportsErrorProvider = StateProvider<bool>((ref) => false);
final libraryReportsEmptyProvider = StateProvider<bool>((ref) => false);

final libraryReportsFutureProvider = FutureProvider<LibraryReportsData>((ref) async {
return await ref.read(libraryRepositoryProvider).getReports(query: ref.watch(repositoryQueryProvider));
});

final libraryReportsProvider = Provider<LibraryReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(libraryReportsFutureProvider),
    manualLoading: ref.watch(libraryReportsLoadingProvider), manualError: ref.watch(libraryReportsErrorProvider), manualEmpty: ref.watch(libraryReportsEmptyProvider),
  );
});
