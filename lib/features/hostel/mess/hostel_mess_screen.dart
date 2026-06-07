import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_module_scaffold.dart';
import '../widgets/hostel_trend_chart.dart';

/// HO-06 — Mess Management.
class HostelMessScreen extends ConsumerWidget {
  const HostelMessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelMessLoadingProvider);
    final isError = ref.watch(hostelMessErrorProvider);
    final isEmpty = ref.watch(hostelMessEmptyProvider);
    final data = ref.watch(hostelMessProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.mess,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HostelMessData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading mess menu'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load mess data.');
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No mess menu data available.',
        icon: Icons.restaurant_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Weekly menu'),
        const SizedBox(height: AksharaSpacing.s3),
        _MenuGrid(menus: data.weeklyMenus),
        const SizedBox(height: AksharaSpacing.s6),
        HostelTrendChart(
          title: 'Mess consumption cost (₹L)',
          points: data.consumptionTrend,
          height: chartHeight,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              '${data.financeIntegrationNote}. MTD cost: ${data.costMtd}.',
          actionLabel: 'Finance reports',
          icon: Icons.account_balance_outlined,
          semanticLabelPrefix: 'Finance integration',
          onAction: () => context.go(RouteNames.financeReports),
        ),
      ],
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.menus});

  final List<HostelMealMenu> menus;

  String _mealLabel(HostelMealType type) => switch (type) {
        HostelMealType.breakfast => 'Breakfast',
        HostelMealType.lunch => 'Lunch',
        HostelMealType.snacks => 'Snacks',
        HostelMealType.dinner => 'Dinner',
      };

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final isMobile = AdminLayout.isMobile(context);

    if (isMobile) {
      return Column(
        children: [
          for (final menu in menus) ...[
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${menu.day} — ${_mealLabel(menu.mealType)}',
                      style: text.titleSmall,
                    ),
                    Text(menu.items, style: text.bodyMedium),
                    Wrap(
                      spacing: AksharaSpacing.s2,
                      children: [
                        for (final tag in menu.dietaryTags)
                          Chip(label: Text(tag), visualDensity: VisualDensity.compact),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Mess menu table, ${menus.length} meals',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Day')),
              DataColumn(label: Text('Meal')),
              DataColumn(label: Text('Menu')),
              DataColumn(label: Text('Dietary tags')),
            ],
            rows: [
              for (final menu in menus)
                DataRow(
                  cells: [
                    DataCell(Text(menu.day)),
                    DataCell(Text(_mealLabel(menu.mealType))),
                    DataCell(Text(menu.items)),
                    DataCell(Text(menu.dietaryTags.join(' · '))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
