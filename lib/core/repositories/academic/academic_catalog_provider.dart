import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_future.dart';
import '../../tenant/tenant_provider.dart';
import '../paginated_result.dart';
import '../repository_query.dart';
import 'academic_catalog_selection.dart';
import 'academic_models.dart';
import 'academic_year_label.dart';
import '../repository_providers.dart';

const _catalogPageSize = 100;

/// Large page query for catalog dropdown population.
final academicCatalogQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref.watch(repositoryQueryProvider).withPage(1, pageSize: _catalogPageSize);
});

final academicCatalogLoadingProvider = StateProvider<bool>((ref) => false);
final academicCatalogErrorProvider = StateProvider<bool>((ref) => false);

final academicCatalogFutureProvider =
    FutureProvider<AcademicCatalogData>((ref) async {
  final repo = ref.read(academicRepositoryProvider);
  final query = ref.watch(academicCatalogQueryProvider);
  final results = await Future.wait<PaginatedResult<dynamic>>([
    repo.getYears(query: query),
    repo.getClasses(query: query),
    repo.getSections(query: query),
    repo.getTeacherAssignments(query: query),
  ]);
  return AcademicCatalogData(
    years: (results[0] as PaginatedResult<AcademicYear>).items,
    classes: (results[1] as PaginatedResult<AcademicClass>).items,
    sections: (results[2] as PaginatedResult<AcademicSection>).items,
    teacherAssignments:
        (results[3] as PaginatedResult<AcademicTeacherAssignment>).items,
  );
});

@immutable
class AcademicCatalogViewState {
  const AcademicCatalogViewState({
    this.isLoading = false,
    this.hasError = false,
    this.data,
  });

  final bool isLoading;
  final bool hasError;
  final AcademicCatalogData? data;
}

final academicCatalogViewStateProvider =
    Provider<AcademicCatalogViewState>((ref) {
  final async = ref.watch(academicCatalogFutureProvider);
  if (ref.watch(academicCatalogLoadingProvider)) {
    return const AcademicCatalogViewState(isLoading: true);
  }
  if (ref.watch(academicCatalogErrorProvider) || async.hasError) {
    return const AcademicCatalogViewState(hasError: true);
  }
  return async.when(
    data: (data) => AcademicCatalogViewState(data: data),
    loading: () => const AcademicCatalogViewState(isLoading: true),
    error: (_, __) => const AcademicCatalogViewState(hasError: true),
  );
});

final academicCatalogProvider = Provider<AcademicCatalogData?>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(academicCatalogFutureProvider),
        manualLoading: ref.watch(academicCatalogLoadingProvider),
        manualError: ref.watch(academicCatalogErrorProvider),
        manualEmpty: false,
      ) ??
      ref.watch(academicCatalogViewStateProvider).data;
});

List<String> _sortedUnique(Iterable<String> values) {
  final unique = values.where((value) => value.isNotEmpty).toSet().toList();
  unique.sort();
  return unique;
}

bool _isActiveCatalogStatus(String status) {
  return status.isEmpty || status == 'active';
}

List<AcademicClass> _sortedClasses(List<AcademicClass> classes) {
  final sorted = List<AcademicClass>.from(classes);
  sorted.sort((a, b) {
    final orderCompare = a.displayOrder.compareTo(b.displayOrder);
    if (orderCompare != 0) return orderCompare;
    return a.className.compareTo(b.className);
  });
  return sorted;
}

final yearOptionsProvider = Provider<List<String>>((ref) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null) return const [];
  return _sortedUnique(
    catalog.years
        .where((year) => _isActiveCatalogStatus(year.status))
        .map((year) => normalizeAcademicYearLabel(year.yearLabel)),
  );
});

final classOptionsProvider = Provider<List<String>>((ref) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null) return const [];
  return _sortedClasses(
    catalog.classes
        .where((item) => _isActiveCatalogStatus(item.status))
        .toList(),
  )
      .map((item) => item.className)
      .toList(growable: false);
});

final sectionOptionsProvider = Provider<List<String>>((ref) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null) return const [];
  return _sortedUnique(
    catalog.sections
        .where((section) => _isActiveCatalogStatus(section.status))
        .map((section) => section.sectionName),
  );
});

final teacherOptionsProvider = Provider<List<String>>((ref) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null) return const [];
  return _sortedUnique(
    catalog.teacherAssignments
        .map((assignment) => assignment.teacherName ?? assignment.teacherId)
        .where((name) => name.isNotEmpty),
  );
});

final classOptionsForYearProvider =
    Provider.family<List<String>, String?>((ref, yearLabel) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null) return const [];
  final normalizedYear = yearLabel == null || yearLabel.isEmpty
      ? ''
      : normalizeAcademicYearLabel(yearLabel);
  String? yearId;
  if (normalizedYear.isNotEmpty) {
    for (final year in catalog.years) {
      if (!_isActiveCatalogStatus(year.status)) continue;
      if (academicYearLabelsEqual(year.yearLabel, normalizedYear)) {
        yearId = year.yearId;
        break;
      }
    }
  }
  final classes = catalog.classes.where((item) {
    if (!_isActiveCatalogStatus(item.status)) return false;
    if (yearId != null && item.academicYearId != yearId) return false;
    return true;
  });
  return _sortedClasses(classes.toList())
      .map((item) => item.className)
      .toList(growable: false);
});

/// Section names filtered by year + class label.
final sectionOptionsForYearClassProvider =
    Provider.family<List<String>, YearClassSelection>((ref, selection) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null) return const [];
  final classes = ref.watch(classOptionsForYearProvider(selection.yearLabel));
  if (selection.className == null ||
      selection.className!.isEmpty ||
      !classes.contains(selection.className)) {
    return const [];
  }
  final classIds = catalog.classes
      .where(
        (item) =>
            _isActiveCatalogStatus(item.status) &&
            item.className == selection.className,
      )
      .map((item) => item.classId)
      .toSet();
  return _sortedUnique(
    catalog.sections
        .where(
          (section) =>
              _isActiveCatalogStatus(section.status) &&
              classIds.contains(section.classId),
        )
        .map((section) => section.sectionName),
  );
});

/// Section names filtered by selected class label (e.g. "5", "10").
final sectionOptionsForClassProvider =
    Provider.family<List<String>, String?>((ref, className) {
  return ref.watch(
    sectionOptionsForYearClassProvider(
      YearClassSelection(className: className),
    ),
  );
});

/// Default year label — current year when flagged, otherwise first option.
final defaultAcademicYearLabelProvider = Provider<String>((ref) {
  final catalog = ref.watch(academicCatalogProvider);
  if (catalog == null || catalog.years.isEmpty) return '2026-27';
  final activeYears =
      catalog.years.where((year) => _isActiveCatalogStatus(year.status));
  for (final year in activeYears) {
    if (year.isCurrent) return normalizeAcademicYearLabel(year.yearLabel);
  }
  final first = activeYears.isNotEmpty ? activeYears.first : catalog.years.first;
  return normalizeAcademicYearLabel(first.yearLabel);
});

void retryAcademicCatalog(WidgetRef ref) {
  ref.invalidate(academicCatalogFutureProvider);
}
