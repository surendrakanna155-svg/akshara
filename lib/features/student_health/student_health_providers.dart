import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import 'student_health_datasource.dart';
import 'student_health_models.dart';

/// PRC-A Batch 2 — the CLINICAL student-health datasource. Only ever consumed
/// by the infirmary console and the full-record screen (both gated on
/// `viewStudentHealthRecord`/`manageStudentHealth`) — NEVER by the teacher
/// care-alert widget, which uses the separate `careAlertDataSourceProvider`
/// (care_alert/care_alert_providers.dart) instead.
final studentHealthDataSourceProvider = Provider<StudentHealthDataSource>(
  (ref) => StudentHealthDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// A student's incident history. autoDispose so a permission change or a
/// closed screen releases clinical data immediately rather than caching it.
final studentIncidentsProvider =
    FutureProvider.autoDispose.family<List<HealthIncident>, String>((ref, studentId) {
  return ref.watch(studentHealthDataSourceProvider).listIncidents(studentId);
});

/// The consolidated full clinical record for one student.
final studentHealthRecordProvider =
    FutureProvider.autoDispose.family<StudentHealthRecord, String>((ref, studentId) {
  return ref.watch(studentHealthDataSourceProvider).studentRecord(studentId);
});

/// "Who accessed this child's health data" — surfaced alongside the record.
final studentHealthAccessLogProvider =
    FutureProvider.autoDispose.family<List<HealthAccessLogEntry>, String>((ref, studentId) {
  return ref.watch(studentHealthDataSourceProvider).accessLog(studentId);
});
