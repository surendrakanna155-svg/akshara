import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../features/transport/transport_models.dart';
import '../parent_active_child_provider.dart';

/// Active child's bus allocation, resolved strictly to that child.
///
/// PAR-8: resolve the allocation for the *active* child only. Match by the live
/// child identity (id/name) or the mock canonical registry; if nothing matches,
/// return null (no allocation) rather than falling back to another child's bus.
final parentTransportAllocationProvider =
    FutureProvider<StudentTransportAllocation?>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  if (child == null) return null;

  final canonical = MockCanonicalStudentRegistry.byParentChildId(
    kAuthChildToProfileId[child.id] ?? child.id,
  );

  final result = await ref.read(transportRepositoryProvider).getAllocations(
        query: ref.watch(parentRepositoryQueryProvider),
      );

  for (final allocation in result.items) {
    final matchesActiveChild = allocation.sisStudentId == child.id ||
        allocation.studentName == child.name;
    final matchesCanonical = canonical != null &&
        (allocation.sisStudentId == canonical.sisStudentId ||
            allocation.studentName == canonical.studentName);
    if (matchesActiveChild || matchesCanonical) {
      return allocation;
    }
  }
  return null;
});
