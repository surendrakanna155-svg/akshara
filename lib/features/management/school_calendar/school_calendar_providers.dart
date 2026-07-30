import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/environment_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/repositories/api/school_calendar/api_school_calendar_repository.dart';
import '../../../core/repositories/api/school_calendar/remote/school_calendar_remote_datasource.dart';
import '../../../core/repositories/interfaces/school_calendar_repository.dart';
import '../../../core/repositories/mock/mock_school_calendar_repository.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'school_calendar_models.dart';

/// PRA-P1-17 — school-calendar repository wiring.
///
/// Self-contained (feature-local) on purpose: it mirrors the mock↔API selection
/// convention peers use in `repository_providers.dart` without editing that
/// shared file, so this feature adds ZERO registration lines to the central
/// provider registry. Enable API mode with
/// `--dart-define=ENABLE_API_MODE=true --dart-define=SCHOOL_CALENDAR_API_ENABLED=true`.
final schoolCalendarApiEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'SCHOOL_CALENDAR_API_ENABLED',
    defaultValue: false,
  );
});

final schoolCalendarRemoteDataSourceProvider =
    Provider<SchoolCalendarRemoteDataSource>(
  (ref) => SchoolCalendarRemoteDataSource(ref.watch(dioProvider)),
);

final apiSchoolCalendarRepositoryProvider =
    Provider<ApiSchoolCalendarRepository>(
  (ref) => ApiSchoolCalendarRepository(
    remote: ref.watch(schoolCalendarRemoteDataSourceProvider),
  ),
);

/// Selects the API-backed repository when the module flag is on, else the mock.
final schoolCalendarRepositoryProvider =
    Provider<SchoolCalendarRepository>((ref) {
  if (ref.watch(schoolCalendarApiEnabledProvider)) {
    return ref.watch(apiSchoolCalendarRepositoryProvider);
  }
  return MockSchoolCalendarRepository();
});

/// Active event-type filter for the list (null = all types).
final schoolCalendarFilterProvider =
    StateProvider<SchoolCalendarEventType?>((ref) => null);

/// Loads calendar events for the current tenant scope + active filter.
final schoolCalendarEventsProvider =
    FutureProvider<List<SchoolCalendarEvent>>((ref) async {
  final repository = ref.watch(schoolCalendarRepositoryProvider);
  final filter = ref.watch(schoolCalendarFilterProvider);
  return repository.listEvents(
    query: ref.watch(repositoryQueryProvider),
    eventType: filter,
  );
});
