import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import '../phase5/phase5_providers.dart';
import 'school_memory_event_screen.dart';

class SchoolMemoriesScreen extends ConsumerWidget {
  const SchoolMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(schoolMemoriesEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('School Memories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(schoolMemoriesRepositoryProvider).createEvent(
                query: ref.read(phase5QueryProvider),
                title: 'New memory event',
                category: 'general',
                description: 'Created from mobile',
              );
          ref.invalidate(schoolMemoriesEventsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: events.when(
        data: (items) {
          if (items.isEmpty) {
            return AksharaEmptyState(
              message: 'Create an event to start collecting school memories.',
              actionLabel: 'Create event',
              onAction: () async {
                await ref.read(schoolMemoriesRepositoryProvider).createEvent(
                      query: ref.read(phase5QueryProvider),
                      title: 'New memory event',
                      category: 'general',
                    );
                ref.invalidate(schoolMemoriesEventsProvider);
              },
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final e = items[index];
              return ListTile(
                title: Text(e.title),
                subtitle: Text('${e.category} · ${e.eventDate}'),
                trailing: Chip(label: Text(e.status)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SchoolMemoryEventScreen(eventId: e.id),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(
          message: 'Could not load memories: $e',
          onRetry: () => ref.invalidate(schoolMemoriesEventsProvider),
        ),
      ),
    );
  }
}
