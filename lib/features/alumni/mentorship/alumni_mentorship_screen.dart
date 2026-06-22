import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-07 — Mentorship.
class AlumniMentorshipScreen extends ConsumerWidget {
  const AlumniMentorshipScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Pending',
    'Completed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniMentorshipLoadingProvider);
    final isError = ref.watch(alumniMentorshipErrorProvider);
    final isEmpty = ref.watch(alumniMentorshipEmptyProvider);
    final pairs = ref.watch(alumniFilteredMentorshipProvider);
    final filterIndex = ref.watch(alumniMentorshipFilterProvider);
    final pageResult = ref.watch(alumniMentorshipPageResultProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.mentorship,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(alumniMentorshipFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAlumni,
        child: FilledButton.icon(
          onPressed: () => showAksharaOperationalPreviewSnackBar(context, action: 'Add mentorship'),
          icon: const Icon(Icons.handshake_outlined, size: 18),
          label: const Text('Match pair'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        pairs: pairs,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<MentorshipPair> pairs,
    required PaginatedResult<MentorshipPair>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading mentorship pairs'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load mentorship pairs.',
      );
    }

    if (isEmpty || pairs.isEmpty) {
      return const AksharaEmptyState(
        message: 'No mentorship pairs match the selected filters.',
        icon: Icons.handshake_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Mentorship pairs'),
        const SizedBox(height: AksharaSpacing.s3),
        _MentorshipTable(pairs: pairs),
        AksharaPaginatedListFooter<MentorshipPair>(
          result: pageResult,
          pageProvider: alumniMentorshipPageProvider,
        ),
      ],
    );
  }
}

class _MentorshipTable extends StatelessWidget {
  const _MentorshipTable({required this.pairs});

  final List<MentorshipPair> pairs;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final pair in pairs) ...[
            _MentorshipCard(pair: pair),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Mentorship table, ${pairs.length} pairs',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Mentor')),
              DataColumn(label: Text('Mentee')),
              DataColumn(label: Text('Batch')),
              DataColumn(label: Text('Focus')),
              DataColumn(label: Text('Sessions')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final pair in pairs)
                DataRow(
                  onSelectChanged: (_) => context.go(
                    RouteNames.alumniProfileDetail(pair.mentorAlumniId),
                  ),
                  cells: [
                    DataCell(Text(pair.mentorName)),
                    DataCell(Text(pair.menteeName)),
                    DataCell(Text(pair.menteeBatch)),
                    DataCell(Text(pair.focusArea)),
                    DataCell(Text('${pair.sessionsCompleted}')),
                    DataCell(_MentorshipStatusChip(status: pair.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentorshipCard extends StatelessWidget {
  const _MentorshipCard({required this.pair});

  final MentorshipPair pair;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Mentor ${pair.mentorName}, mentee ${pair.menteeName}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pair.mentorName} → ${pair.menteeName}',
                      style: text.titleSmall,
                    ),
                  ),
                  _MentorshipStatusChip(status: pair.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(pair.focusArea, style: text.bodyMedium),
              Text(
                '${pair.menteeBatch} · ${pair.sessionsCompleted} sessions',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentorshipStatusChip extends StatelessWidget {
  const _MentorshipStatusChip({required this.status});

  final MentorshipStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      MentorshipStatus.active => ('Active', KpiAccent.success),
      MentorshipStatus.pending => ('Pending', KpiAccent.warning),
      MentorshipStatus.completed => ('Completed', KpiAccent.neutral),
      MentorshipStatus.onHold => ('On hold', KpiAccent.error),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
