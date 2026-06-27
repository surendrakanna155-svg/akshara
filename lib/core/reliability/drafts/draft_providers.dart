import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tenant/tenant_provider.dart';
import '../reliability_providers.dart';
import 'draft_controller.dart';

/// A [DraftController] scoped to the currently signed-in user + school.
///
/// Drafts are keyed by `(draftKey, userId, schoolId)` so they are private to the
/// user who created them and are wiped on logout (see `AuthNotifier.logout`).
/// Screens read this to autosave / recover in-progress forms.
final draftControllerProvider = Provider<DraftController>((ref) {
  final tenant = ref.watch(tenantContextProvider);
  return DraftController(
    ref.watch(reliabilityStoreProvider),
    userId: tenant.userId,
    schoolId: tenant.schoolId,
  );
});
