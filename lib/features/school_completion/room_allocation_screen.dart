import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

/// v15.3 — Room and lab allocation for timetables.
class RoomAllocationScreen extends ConsumerWidget {
  const RoomAllocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(academicRoomsProvider);
    final catalog = ref.watch(academicCatalogFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Room & Lab Allocation')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: catalog.isLoading
            ? null
            : () async {
                final years = catalog.value?.years;
                final yearId = years != null && years.isNotEmpty ? years.first.yearId : 'year_1';
                await ref.read(schoolCompletionRepositoryProvider).allocateRooms(
                      query: ref.read(schoolCompletionQueryProvider),
                      academicYearId: yearId,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rooms allocated to timetable periods')),
                  );
                }
              },
        icon: const Icon(Icons.meeting_room_outlined),
        label: const Text('Auto-allocate'),
      ),
      body: ErpAsyncBody(
        state: resolveErpAsync(rooms, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No rooms available.',
        onRetry: () => ref.invalidate(academicRoomsProvider),
        builder: (items) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            const AksharaSectionHeader(title: 'Classrooms'),
            ...items.where((r) => r.roomType == 'classroom').map(
                  (r) => ListTile(
                    leading: const Icon(Icons.class_outlined),
                    title: Text(r.roomLabel),
                    subtitle: Text('Capacity ${r.capacity}'),
                  ),
                ),
            const SizedBox(height: 16),
            const AksharaSectionHeader(title: 'Labs'),
            ...items.where((r) => r.roomType == 'lab').map(
                  (r) => ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: Text(r.roomLabel),
                    subtitle: Text('Capacity ${r.capacity}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
