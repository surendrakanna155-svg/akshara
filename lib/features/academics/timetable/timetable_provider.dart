import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'timetable_models.dart';

const kTimetableDemoYearId = 'mock-year-current';

final timetableQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final timetableSelectedIdProvider = StateProvider<String?>((ref) => 'tt_mock_2');

final timetableSummaryProvider = FutureProvider<TimetableSummary>((ref) async {
  return ref.read(timetableRepositoryProvider).getSummary(
        query: ref.watch(timetableQueryProvider),
        academicYearId: kTimetableDemoYearId,
      );
});

final timetableListProvider = FutureProvider<List<TimetableEntry>>((ref) async {
  return ref.read(timetableRepositoryProvider).getTimetables(
        query: ref.watch(timetableQueryProvider),
        academicYearId: kTimetableDemoYearId,
      );
});

final timetableWorkloadProvider = FutureProvider<List<TeacherWorkloadEntry>>((ref) async {
  return ref.read(timetableRepositoryProvider).getWorkload(
        query: ref.watch(timetableQueryProvider),
        academicYearId: kTimetableDemoYearId,
      );
});

final timetableConflictsProvider = FutureProvider<TimetableConflictsBundle>((ref) async {
  return ref.read(timetableRepositoryProvider).getConflicts(
        query: ref.watch(timetableQueryProvider),
        academicYearId: kTimetableDemoYearId,
      );
});

final timetableCanViewProvider = Provider<bool>(
  (ref) => ref.watch(rbacServiceProvider).hasPermission(Permission.viewAcademicTimetable),
);

final timetableCanManageProvider = Provider<bool>(
  (ref) => ref.watch(rbacServiceProvider).hasPermission(Permission.manageAcademicTimetable),
);

final timetableCanPublishProvider = Provider<bool>(
  (ref) => ref.watch(rbacServiceProvider).hasPermission(Permission.publishAcademicTimetable),
);

final timetableMutationsProvider =
    AsyncNotifierProvider<TimetableMutationsNotifier, void>(TimetableMutationsNotifier.new);

class TimetableMutationsNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> generate({String? sectionId}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(timetableRepositoryProvider).generate(
            query: ref.read(timetableQueryProvider),
            request: GenerateTimetableRequest(
              academicYearId: kTimetableDemoYearId,
              sectionId: sectionId,
            ),
          );
      ref.invalidate(timetableSummaryProvider);
      ref.invalidate(timetableListProvider);
      ref.invalidate(timetableConflictsProvider);
      ref.invalidate(timetableWorkloadProvider);
    });
  }

  Future<void> validate(String timetableId) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(timetableRepositoryProvider).validate(
            query: ref.read(timetableQueryProvider),
            timetableId: timetableId,
          );
      ref.invalidate(timetableSummaryProvider);
      ref.invalidate(timetableListProvider);
    });
  }

  Future<void> publish(String timetableId) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(timetableRepositoryProvider).publish(
            query: ref.read(timetableQueryProvider),
            timetableId: timetableId,
          );
      ref.invalidate(timetableSummaryProvider);
      ref.invalidate(timetableListProvider);
    });
  }
}

void invalidateTimetableReads(WidgetRef ref) {
  ref.invalidate(timetableSummaryProvider);
  ref.invalidate(timetableListProvider);
  ref.invalidate(timetableWorkloadProvider);
  ref.invalidate(timetableConflictsProvider);
}
