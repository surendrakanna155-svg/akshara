import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

/// v13.1 — Room/lab allocation, exam timetable, optimization scoring.
class TimetableIntelligenceScreen extends ConsumerStatefulWidget {
  const TimetableIntelligenceScreen({super.key});

  @override
  ConsumerState<TimetableIntelligenceScreen> createState() =>
      _TimetableIntelligenceScreenState();
}

class _TimetableIntelligenceScreenState extends ConsumerState<TimetableIntelligenceScreen> {
  final _roomLabel = TextEditingController(text: 'Lab 1');
  bool _creatingRoom = false;

  @override
  void dispose() {
    _roomLabel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(academicRoomsProvider);
    final catalog = ref.watch(academicCatalogFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable Intelligence')),
      body: ErpAsyncBody(
        state: resolveErpAsync(catalog, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No academic catalog available.',
        onRetry: () => ref.invalidate(academicCatalogFutureProvider),
        builder: (data) {
          final yearId = data.years.isNotEmpty ? data.years.first.yearId : 'year_1';
          final intelligence = ref.watch(timetableIntelligenceProvider(yearId));
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              ErpAsyncBody(
                state: resolveErpAsync(intelligence, isDataEmpty: (_) => false),
                loadingLabel: 'Loading',
                emptyMessage: 'No timetable intelligence available.',
                onRetry: () => ref.invalidate(timetableIntelligenceProvider(yearId)),
                builder: (result) => _IntelligencePanel(result: result),
              ),
              const Divider(height: 32),
              const Text('Rooms & labs', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _roomLabel,
                      decoration: const InputDecoration(labelText: 'Room label'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _creatingRoom ? null : () => _createRoom(context),
                    child: const Text('Add lab'),
                  ),
                ],
              ),
              ErpAsyncBody(
                state: resolveErpAsync(rooms, isDataEmpty: (_) => false),
                loadingLabel: 'Loading',
                emptyMessage: 'No rooms available.',
                onRetry: () => ref.invalidate(academicRoomsProvider),
                builder: (items) => Column(
                  children: items
                      .map(
                        (r) => ListTile(
                          title: Text(r.roomLabel),
                          subtitle: Text('${r.roomType} · capacity ${r.capacity}'),
                          trailing: Text(r.status),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    setState(() => _creatingRoom = true);
    try {
      await ref.read(schoolCompletionRepositoryProvider).createRoom(
            query: ref.read(schoolCompletionQueryProvider),
            roomLabel: _roomLabel.text.trim(),
            roomType: 'lab',
            capacity: 30,
          );
      ref.invalidate(academicRoomsProvider);
    } finally {
      if (mounted) setState(() => _creatingRoom = false);
    }
  }
}

class _IntelligencePanel extends StatelessWidget {
  const _IntelligencePanel({required this.result});

  final TimetableIntelligenceResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: const Text('Intelligence score'),
          trailing: Text('${result.intelligenceScore}/100',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          title: const Text('Exam periods scheduled'),
          trailing: Text('${result.examCount}'),
        ),
        ListTile(
          title: const Text('Conflicts'),
          trailing: Text('${result.conflictCount}'),
        ),
        if (result.conflictCount > 0)
          const AksharaWarningBanner(message: 'Resolve timetable conflicts before publishing'),
        const SizedBox(height: 8),
        const Text('Room utilization', style: TextStyle(fontWeight: FontWeight.bold)),
        ...result.roomUtilization.map(
          (u) => ListTile(
            title: Text(u.roomLabel),
            subtitle: Text('${u.periodCount} periods · cap ${u.capacity}'),
          ),
        ),
      ],
    );
  }
}
