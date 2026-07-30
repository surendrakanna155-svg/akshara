import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../student_health_models.dart';
import 'care_alert_datasource.dart';

/// The narrow teacher-safe datasource — deliberately separate from
/// `studentHealthDataSourceProvider` (see care_alert_datasource.dart).
final careAlertDataSourceProvider = Provider<CareAlertDataSource>(
  (ref) => CareAlertDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// A student's active care alerts (teacher-safe fields only). autoDispose so
/// the alert never outlives the widget that requested it, e.g. across a
/// permission change.
final careAlertProvider =
    FutureProvider.autoDispose.family<List<CareAlert>, String>((ref, studentId) {
  return ref.watch(careAlertDataSourceProvider).fetch(studentId);
});
