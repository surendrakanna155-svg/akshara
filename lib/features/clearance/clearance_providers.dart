import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import 'clearance_datasource.dart';
import 'clearance_models.dart';

/// SCE-1 slice 4 — the clearance datasource + a per-student report future.
final clearanceDataSourceProvider = Provider<ClearanceDataSource>(
  (ref) => ClearanceDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// The consolidated no-dues report for a student (transfer_certificate lens).
/// autoDispose + family so each open fetches fresh and is released on close.
final studentClearanceReportProvider =
    FutureProvider.autoDispose.family<ClearanceReport, String>((ref, studentId) {
  return ref.watch(clearanceDataSourceProvider).report(studentId: studentId);
});

/// The pending waiver approver queue (approveClearanceWaiver holders).
final pendingClearanceWaiversProvider =
    FutureProvider.autoDispose<List<ClearanceWaiver>>((ref) {
  return ref.watch(clearanceDataSourceProvider).pendingWaivers();
});
