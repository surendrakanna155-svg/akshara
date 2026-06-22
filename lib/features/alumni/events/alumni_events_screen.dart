import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-04 — Events.
class AlumniEventsScreen extends ConsumerWidget {
  const AlumniEventsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Upcoming',
    'Ongoing',
    'Completed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniEventsLoadingProvider);
    final isError = ref.watch(alumniEventsErrorProvider);
    final isEmpty = ref.watch(alumniEventsEmptyProvider);
    final events = ref.watch(alumniFilteredEventsProvider);
    final filterIndex = ref.watch(alumniEventsFilterProvider);
    final pageResult = ref.watch(alumniEventsPageResultProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.events,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(alumniEventsFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAlumni,
        child: FilledButton.icon(
          onPressed: () => showAksharaOperationalPreviewSnackBar(context, action: 'Create event'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New event'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        events: events,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<AlumniEvent> events,
    required PaginatedResult<AlumniEvent>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading alumni events'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load alumni events.');
    }

    if (isEmpty || events.isEmpty) {
      return const AksharaEmptyState(
        message: 'No events match the selected filters.',
        icon: Icons.event_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Event calendar'),
        const SizedBox(height: AksharaSpacing.s3),
        _EventsTable(events: events),
        AksharaPaginatedListFooter<AlumniEvent>(
          result: pageResult,
          pageProvider: alumniEventsPageProvider,
        ),
      ],
    );
  }
}

class _EventsTable extends StatelessWidget {
  const _EventsTable({required this.events});

  final List<AlumniEvent> events;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final event in events) ...[
            _EventCard(event: event),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Events table, ${events.length} events',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Venue')),
              DataColumn(label: Text('RSVPs')),
              DataColumn(label: Text('Organizer')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final event in events)
                DataRow(
                  cells: [
                    DataCell(Text(event.title)),
                    DataCell(Text(event.date)),
                    DataCell(Text(event.venue)),
                    DataCell(Text('${event.registrations}/${event.capacity}')),
                    DataCell(Text(event.organizer)),
                    DataCell(_EventStatusChip(status: event.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final AlumniEvent event;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Event ${event.title}, ${event.date}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(event.title, style: text.titleSmall)),
                  _EventStatusChip(status: event.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text('${event.date} · ${event.venue}', style: text.bodySmall),
              Text(
                '${event.registrations}/${event.capacity} RSVPs · ${event.organizer}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventStatusChip extends StatelessWidget {
  const _EventStatusChip({required this.status});

  final AlumniEventStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AlumniEventStatus.upcoming => ('Upcoming', KpiAccent.primary),
      AlumniEventStatus.ongoing => ('Ongoing', KpiAccent.success),
      AlumniEventStatus.completed => ('Completed', KpiAccent.neutral),
      AlumniEventStatus.cancelled => ('Cancelled', KpiAccent.error),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
