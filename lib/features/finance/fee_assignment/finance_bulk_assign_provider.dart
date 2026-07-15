import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../sis/sis_models.dart';

/// PRC-A gap fix — bulk/class-wide fee-structure assignment. Reuses
/// [SisRepository.getStudents] (the same student roster the rest of the app
/// reads from) so "every student in Class X" needs no bespoke fetch path. A
/// large single page is pulled and the class filter applied client-side —
/// mirroring sis_registry_provider's own class-match idiom, which is exactly
/// what mock mode already does (the API layer may additionally honour a
/// server-side `className` filter, but the client-side pass keeps both modes
/// consistent without depending on it).
const _bulkAssignStudentPageSize = 200;

final financeBulkAssignClassFilterProvider =
    StateProvider<String?>((ref) => null);

final financeBulkAssignStudentsQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref
      .watch(repositoryQueryProvider)
      .withPage(1, pageSize: _bulkAssignStudentPageSize);
});

final financeBulkAssignStudentsFutureProvider =
    FutureProvider<PaginatedResult<SisStudent>>((ref) async {
  return ref.read(sisRepositoryProvider).getStudents(
        query: ref.watch(financeBulkAssignStudentsQueryProvider),
      );
});

final financeBulkAssignAllStudentsProvider = Provider<List<SisStudent>>((ref) {
  return ref.watch(financeBulkAssignStudentsFutureProvider).maybeWhen(
        data: (result) => result.items,
        orElse: () => const <SisStudent>[],
      );
});

/// The roster for the currently-selected class only.
final financeBulkAssignClassRosterProvider = Provider<List<SisStudent>>((ref) {
  final all = ref.watch(financeBulkAssignAllStudentsProvider);
  final className = ref.watch(financeBulkAssignClassFilterProvider);
  if (className == null || className.isEmpty) return all;
  return all.where((s) => s.classLabel == className).toList(growable: false);
});
