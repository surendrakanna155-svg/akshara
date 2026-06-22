import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// ACC-06 — Support Tickets.
class ControlCenterSupportScreen extends ConsumerWidget {
  const ControlCenterSupportScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Open',
    'In progress',
    'Resolved',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterSupportLoadingProvider);
    final isError = ref.watch(controlCenterSupportErrorProvider);
    final isEmpty = ref.watch(controlCenterSupportEmptyProvider);
    final tickets = ref.watch(controlCenterFilteredSupportProvider);
    final filterIndex = ref.watch(controlCenterSupportFilterProvider);
    final pageResult = ref.watch(controlCenterSupportPageResultProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.support,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(controlCenterSupportFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        tickets: tickets,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<SupportTicket> tickets,
    required PaginatedResult<SupportTicket>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading support tickets'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load support tickets.',
      );
    }

    if (isEmpty || tickets.isEmpty) {
      return const AksharaEmptyState(
        message: 'No support tickets match the selected filters.',
        icon: Icons.support_agent_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Support tickets'),
        const SizedBox(height: AksharaSpacing.s3),
        if (AdminLayout.useCardLayout(context))
          Column(
            children: [
              for (final ticket in tickets) ...[
                _TicketCard(ticket: ticket),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          _TicketsTable(tickets: tickets),
        AksharaPaginatedListFooter<SupportTicket>(
          result: pageResult,
          pageProvider: controlCenterSupportPageProvider,
        ),
      ],
    );
  }
}

class _TicketsTable extends StatelessWidget {
  const _TicketsTable({required this.tickets});

  final List<SupportTicket> tickets;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Support tickets table, ${tickets.length} tickets',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Ticket')),
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('School')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Priority')),
              DataColumn(label: Text('SLA')),
              DataColumn(label: Text('Assignee')),
            ],
            rows: [
              for (final ticket in tickets)
                DataRow(
                  cells: [
                    DataCell(Text(ticket.id)),
                    DataCell(Text(ticket.subject)),
                    DataCell(Text(ticket.schoolName)),
                    DataCell(_TicketStatusChip(status: ticket.status)),
                    DataCell(Text(ticket.priority)),
                    DataCell(Text(ticket.slaRemaining)),
                    DataCell(Text(ticket.assignee)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(ticket.subject),
        subtitle: Text('${ticket.schoolName} · SLA ${ticket.slaRemaining}'),
        trailing: _TicketStatusChip(status: ticket.status),
      ),
    );
  }
}

class _TicketStatusChip extends StatelessWidget {
  const _TicketStatusChip({required this.status});

  final SupportTicketStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      SupportTicketStatus.open => ('Open', KpiAccent.error),
      SupportTicketStatus.inProgress => ('In progress', KpiAccent.warning),
      SupportTicketStatus.resolved => ('Resolved', KpiAccent.success),
      SupportTicketStatus.closed => ('Closed', KpiAccent.neutral),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Ticket status: $label',
    );
  }
}
