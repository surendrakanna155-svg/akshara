import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/repository_providers.dart';
import '../../../../core/security/permissions.dart';
import '../../../../core/security/rbac_service.dart';
import '../timetable_models.dart';
import '../timetable_provider.dart';

/// The day being viewed (defaults to today). Substitutions are a dated overlay,
/// so this drives which cover picture is loaded from the backend.
final selectedTimetableDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// YYYY-MM-DD for the selected date, matching the backend `sub_date` format.
String formatSubDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Server-resolved substitutions + on-leave teachers for the selected date.
/// The on-leave set now comes from the server (no client-side derivation).
final dailySubstitutionsProvider =
    FutureProvider.autoDispose<DailySubstitutionsBundle>((ref) async {
  final date = formatSubDate(ref.watch(selectedTimetableDateProvider));
  return ref.read(timetableRepositoryProvider).listSubstitutions(
        query: ref.watch(timetableQueryProvider),
        date: date,
      );
});

/// Writes to substitutions are gated by the timetable-manage permission (same
/// gate the other timetable mutations use).
final substitutionCanManageProvider = Provider<bool>(
  (ref) => ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.manageAcademicTimetable),
);

void stepSelectedDate(WidgetRef ref, int days) {
  ref.read(selectedTimetableDateProvider.notifier).update(
        (d) => d.add(Duration(days: days)),
      );
}

final substitutionMutationsProvider =
    AsyncNotifierProvider<SubstitutionMutationsNotifier, void>(
  SubstitutionMutationsNotifier.new,
);

class SubstitutionMutationsNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Create (or re-assign) a cover. Rethrows [SubstituteBusyException] so the UI
  /// can surface the friendly 409 message inline; other errors land in [state].
  Future<TimetableSubstitution?> create({
    required String periodId,
    required String substituteTeacherId,
    String? reason,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    final subDate = formatSubDate(ref.read(selectedTimetableDateProvider));
    try {
      final created = await ref.read(timetableRepositoryProvider).createSubstitution(
            query: ref.read(timetableQueryProvider),
            request: CreateSubstitutionRequest(
              periodId: periodId,
              subDate: subDate,
              substituteTeacherId: substituteTeacherId,
              reason: reason,
            ),
          );
      state = const AsyncData(null);
      ref.invalidate(dailySubstitutionsProvider);
      return created;
    } on SubstituteBusyException {
      state = const AsyncData(null);
      rethrow;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(timetableRepositoryProvider).deleteSubstitution(
            query: ref.read(timetableQueryProvider),
            id: id,
          );
      ref.invalidate(dailySubstitutionsProvider);
    });
  }
}
