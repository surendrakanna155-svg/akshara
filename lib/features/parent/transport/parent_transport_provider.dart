import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../core/repositories/repository_config.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../features/transport/transport_models.dart';
import '../parent_active_child_provider.dart';

/// Why the parent transport surface has no allocation to show.
///
/// BUS-003 — "the school has not enabled this yet" and "your child has no bus"
/// are different facts and must render differently. Collapsing them (or
/// surfacing the underlying 403 as a generic failure) teaches parents the app
/// is broken when it is merely not switched on.
enum ParentTransportAvailability {
  /// Parent-facing transport is not live for this build/school (BUS-095 pending).
  notEnabled,

  /// Transport is live, but this child has no allocation on file.
  noAllocation,

  /// Transport is live and this child has an allocation.
  available,
}

@immutable
class ParentTransportView {
  const ParentTransportView._(this.availability, this.allocation);

  const ParentTransportView.notEnabled()
      : this._(ParentTransportAvailability.notEnabled, null);

  const ParentTransportView.noAllocation()
      : this._(ParentTransportAvailability.noAllocation, null);

  const ParentTransportView.available(StudentTransportAllocation allocation)
      : this._(ParentTransportAvailability.available, allocation);

  final ParentTransportAvailability availability;
  final StudentTransportAllocation? allocation;

  bool get isEnabled => availability != ParentTransportAvailability.notEnabled;
}

/// Active child's bus allocation, resolved strictly to that child.
///
/// PAR-8: resolve the allocation for the *active* child only. Match by the live
/// child identity (id/name) or the mock canonical registry; if nothing matches,
/// return "no allocation" rather than falling back to another child's bus.
///
/// BUS-003: when parent transport is not enabled this issues NO network call.
/// The transport list endpoint requires `viewTransport` + school scope, which a
/// parent session does not have — calling it produced a 403 rendered to the
/// parent as an error screen. BUS-059/BUS-095 replace the list-scan below with a
/// parent-scoped single-child endpoint; until then the surface stays honest.
final parentTransportAllocationProvider =
    FutureProvider<ParentTransportView>((ref) async {
  if (!ref.watch(parentTransportEnabledProvider)) {
    return const ParentTransportView.notEnabled();
  }

  final child = ref.watch(parentActiveChildProvider);
  if (child == null) return const ParentTransportView.noAllocation();

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
      return ParentTransportView.available(allocation);
    }
  }
  return const ParentTransportView.noAllocation();
});
