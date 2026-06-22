import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_segment_panel.dart';
import '../widgets/hr_trend_chart.dart';

/// HR-07 — Recruitment.
class HrRecruitmentScreen extends ConsumerWidget {
  const HrRecruitmentScreen({super.key});

  static const List<String> filterLabels = [
    'All stages',
    'Applied',
    'Interview',
    'Joined',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrRecruitmentLoadingProvider);
    final isError = ref.watch(hrRecruitmentErrorProvider);
    final isEmpty = ref.watch(hrRecruitmentEmptyProvider);
    final data = ref.watch(hrRecruitmentProvider);
    final candidates = ref.watch(hrFilteredCandidatesProvider);
    final filterIndex = ref.watch(hrRecruitmentFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.recruitment,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrRecruitmentFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
        candidates: candidates,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HrRecruitmentData? data,
    required List<HrCandidate> candidates,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading recruitment'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load recruitment pipeline.',
      );
    }

    if (isEmpty || data == null || candidates.isEmpty) {
      return const AksharaEmptyState(
        message: 'No candidates match the selected filters.',
        icon: Icons.person_search_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Recruitment pipeline'),
        Text(
          '${data.openPositions} open positions',
          style: context.aksharaText.bodySmall,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        _CandidatesTable(candidates: candidates),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          HrSegmentPanel(
            title: 'Pipeline stages',
            segments: data.pipelineCounts,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          HrTrendChart(
            title: 'Hires per quarter',
            points: data.hiringTrend,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HrSegmentPanel(
                  title: 'Pipeline stages',
                  segments: data.pipelineCounts,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: HrTrendChart(
                  title: 'Hires per quarter',
                  points: data.hiringTrend,
                  height: chartHeight,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CandidatesTable extends StatelessWidget {
  const _CandidatesTable({required this.candidates});

  final List<HrCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final candidate in candidates) ...[
            _CandidateCard(candidate: candidate),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Candidates table, ${candidates.length} applicants',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Applied')),
              DataColumn(label: Text('Experience')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Stage')),
            ],
            rows: [
              for (final candidate in candidates)
                DataRow(
                  cells: [
                    DataCell(Text(candidate.name)),
                    DataCell(Text(candidate.role)),
                    DataCell(Text(candidate.department.name)),
                    DataCell(Text(candidate.appliedOn)),
                    DataCell(Text(candidate.experience)),
                    DataCell(Text(candidate.source)),
                    DataCell(_StageChip(stage: candidate.stage)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final HrCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Candidate ${candidate.name}, ${candidate.role}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(candidate.name, style: text.titleSmall),
              Text(candidate.role, style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              _StageChip(stage: candidate.stage),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final HrRecruitmentStage stage;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (stage) {
      HrRecruitmentStage.applied => ('Applied', KpiAccent.neutral),
      HrRecruitmentStage.screening => ('Screening', KpiAccent.primary),
      HrRecruitmentStage.interview => ('Interview', KpiAccent.warning),
      HrRecruitmentStage.selected => ('Selected', KpiAccent.success),
      HrRecruitmentStage.joined => ('Joined', KpiAccent.success),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
