import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/continuity/continuity_models.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';

final continuityStudentIdProvider = StateProvider<String>(
  (ref) => 'SIS-STU-10418',
);
final continuityFromClassProvider = StateProvider<String>((ref) => '7');
final continuityFromSectionProvider = StateProvider<String>((ref) => 'A');
final continuityToClassProvider = StateProvider<String>((ref) => '8');
final continuityToSectionProvider = StateProvider<String>((ref) => 'A');
final continuityAcademicYearProvider = StateProvider<String>((ref) => '2026-27');
final continuityPlanIdProvider = StateProvider<String?>((ref) => null);

final continuityPreviewProvider = FutureProvider<ContinuityMigrationPlan?>((ref) async {
  final planId = ref.watch(continuityPlanIdProvider);
  if (planId == null) return null;
  final audit = await ref.read(continuityRepositoryProvider).getContinuityAuditTrail(
        query: ref.watch(repositoryQueryProvider),
        migrationId: planId,
      );
  if (audit.isEmpty) return null;
  return ref.read(continuityRepositoryProvider).previewContinuityMigration(
        query: ref.watch(repositoryQueryProvider),
        studentId: ref.watch(continuityStudentIdProvider),
        fromClass: ref.watch(continuityFromClassProvider),
        fromSection: ref.watch(continuityFromSectionProvider),
        toClass: ref.watch(continuityToClassProvider),
        toSection: ref.watch(continuityToSectionProvider),
        academicYear: ref.watch(continuityAcademicYearProvider),
      );
});
