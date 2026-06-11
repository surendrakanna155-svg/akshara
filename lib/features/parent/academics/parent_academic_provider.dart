import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../parent_active_child_provider.dart';
import 'parent_academic_models.dart';

final parentAcademicSummaryProvider = FutureProvider<ParentAcademicSummary>((ref) async {
  final studentId = ref.watch(parentActiveStudentIdProvider);
  return ref.read(parentRepositoryProvider).getAcademicSummary(
        query: ref.watch(repositoryQueryProvider),
        studentId: studentId,
      );
});

final parentPrintableReportProvider = FutureProvider<String>((ref) async {
  final studentId = ref.watch(parentActiveStudentIdProvider);
  return ref.read(parentRepositoryProvider).getPrintableReport(
        query: ref.watch(repositoryQueryProvider),
        studentId: studentId,
      );
});
