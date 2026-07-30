import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'domain/support_models.dart';
import 'support_providers.dart';
import 'support_ui.dart';

/// ASIP Phase 1 screen (b) — the reporter's list of issues raised with NIKSHA
/// Support, with status filter chips, public refs and pull-to-refresh.
class MyReportedIssuesScreen extends ConsumerStatefulWidget {
  const MyReportedIssuesScreen({super.key});

  @override
  ConsumerState<MyReportedIssuesScreen> createState() =>
      _MyReportedIssuesScreenState();
}

class _MyReportedIssuesScreenState
    extends ConsumerState<MyReportedIssuesScreen> {
  SupportStatus? _status;

  static const _filters = <(String, SupportStatus?)>[
    ('All', null),
    ('New', SupportStatus.newIncident),
    ('In progress', SupportStatus.inProgress),
    ('Awaiting you', SupportStatus.awaitingCustomer),
    ('Resolved', SupportStatus.resolved),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myReportedIncidentsProvider(_status));

    return Scaffold(
      key: QaTestKeys.supportMyIssuesScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: const AksharaAppBar(
        titleText: 'My reported issues',
        subtitle: 'Issues you raised with NIKSHA Support',
        trailingPadding: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: QaTestKeys.supportReportIssueButton,
        onPressed: () => context.push(RouteNames.supportNew),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Report an issue'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            selected: _status,
            filters: _filters,
            onSelected: (s) => setState(() => _status = s),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(myReportedIncidentsProvider(_status)),
              child: async.when(
                loading: () => const AksharaLoadingState(),
                error: (_, __) => AksharaErrorState(
                  message: 'Unable to load your issues.',
                  onRetry: () =>
                      ref.invalidate(myReportedIncidentsProvider(_status)),
                ),
                data: (result) {
                  if (result.items.isEmpty) {
                    return _EmptyList(
                      filtered: _status != null,
                      onReport: () => context.push(RouteNames.supportNew),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AksharaSpacing.mobileMargin,
                      AksharaSpacing.s4,
                      AksharaSpacing.mobileMargin,
                      AksharaSpacing.s16,
                    ),
                    itemCount: result.items.length,
                    itemBuilder: (context, index) =>
                        _IncidentCard(incident: result.items[index]),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AksharaSpacing.s3),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  final SupportStatus? selected;
  final List<(String, SupportStatus?)> filters;
  final ValueChanged<SupportStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.mobileMargin,
        vertical: AksharaSpacing.s3,
      ),
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              label: Text(filter.$1),
              selected: selected == filter.$2,
              onSelected: (_) => onSelected(filter.$2),
            ),
            const SizedBox(width: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final SupportIncident incident;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      child: InkWell(
        key: QaTestKeys.supportIncidentCard(incident.id),
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        onTap: () =>
            context.push(RouteNames.supportIncidentDetail(incident.id)),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      incident.title,
                      style: text.titleSmall.copyWith(color: colors.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  AksharaStatusChip(
                    label: incident.status.label,
                    tone: supportStatusTone(incident.status),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                incident.description,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Row(
                children: [
                  Text(
                    incident.publicRef,
                    style: text.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (incident.moduleKey != null) ...[
                    Text(
                      '  ·  ${formatSupportCategory(incident.moduleKey)}',
                      style: text.labelSmall
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    supportRelativeTime(incident.updatedAt),
                    style: text.labelSmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.filtered, required this.onReport});

  final bool filtered;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AksharaSpacing.s16),
        AksharaEmptyState(
          icon: Icons.support_agent_outlined,
          title: filtered ? 'No issues in this filter' : 'No reported issues',
          message: filtered
              ? 'Try a different status filter.'
              : 'When something is not working, report it here and NIKSHA '
                  'Support will investigate. We attach the technical details '
                  'for you automatically.',
          actionLabel: filtered ? null : 'Report an issue',
          onAction: filtered ? null : onReport,
        ),
      ],
    );
  }
}
