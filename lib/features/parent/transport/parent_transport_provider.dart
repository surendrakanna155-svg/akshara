import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../features/transport/transport_models.dart';
import '../parent_active_child_provider.dart';

/// Active child's bus allocation resolved via canonical SIS identity.
final parentTransportAllocationProvider =
    FutureProvider<StudentTransportAllocation?>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  final profileChildId = child != null
      ? (kAuthChildToProfileId[child.id] ?? child.id)
      : 'child_ravi';
  final canonical = MockCanonicalStudentRegistry.byParentChildId(profileChildId) ??
      MockCanonicalStudentRegistry.primaryMobileStudent;

  final result = await ref.read(transportRepositoryProvider).getAllocations(
        query: ref.watch(repositoryQueryProvider),
      );

  for (final allocation in result.items) {
    if (allocation.sisStudentId == canonical.sisStudentId ||
        allocation.studentName == canonical.studentName) {
      return allocation;
    }
  }
  return result.items.isEmpty ? null : result.items.first;
});
