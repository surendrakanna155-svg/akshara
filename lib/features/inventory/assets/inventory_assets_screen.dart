import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_pagination_bar.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../../core/repositories/paginated_result.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../widgets/inventory_kpi_row.dart';
import '../widgets/inventory_module_scaffold.dart';

/// INV-02 — Assets.
class InventoryAssetsScreen extends ConsumerWidget {
  const InventoryAssetsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Available',
    'Allocated',
    'Maintenance',
    'Retired',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryAssetsLoadingProvider);
    final isError = ref.watch(inventoryAssetsErrorProvider);
    final isEmpty = ref.watch(inventoryAssetsEmptyProvider);
    final assets = ref.watch(inventoryFilteredAssetsProvider);
    final filterIndex = ref.watch(inventoryAssetsFilterProvider);
    final pageResult = ref.watch(inventoryAssetsPageResultProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.assets,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryAssetsFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        ref: ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        assets: assets,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WidgetRef ref,
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<InventoryAsset> assets,
    required PaginatedResult<InventoryAsset>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading assets'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load assets.');
    }

    if (isEmpty || assets.isEmpty) {
      return const AksharaEmptyState(
        message: 'No assets match the selected filters.',
        icon: Icons.inventory_2_outlined,
      );
    }

    final allocatedCount = assets
        .where((a) => a.status == InventoryAssetStatus.allocated)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InventoryKpiRow(
          desktopColumns: 3,
          kpis: [
            InventoryKpi(
              id: 'total',
              value: '${assets.length}',
              label: 'Assets shown',
              icon: Icons.inventory_2_outlined,
              accentName: 'primary',
            ),
            InventoryKpi(
              id: 'allocated',
              value: '$allocatedCount',
              label: 'Allocated',
              icon: Icons.assignment_outlined,
              accentName: 'success',
            ),
            const InventoryKpi(
              id: 'value',
              value: '₹94.2L',
              label: 'Total value',
              icon: Icons.account_balance_outlined,
              accentName: 'neutral',
              detail: 'Finance asset register',
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Asset registry'),
        const SizedBox(height: AksharaSpacing.s3),
        _AssetTable(assets: assets),
        if (pageResult != null) ...[
          const SizedBox(height: AksharaSpacing.s4),
          AksharaPaginationBar<InventoryAsset>(
            result: pageResult,
            onPageChanged: (page) =>
                ref.read(inventoryAssetsPageProvider.notifier).state = page,
          ),
        ],
      ],
    );
  }
}

class _AssetTable extends StatelessWidget {
  const _AssetTable({required this.assets});

  final List<InventoryAsset> assets;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final asset in assets) ...[
            _AssetCard(asset: asset),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Asset registry, ${assets.length} assets',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Tag')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Value')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Finance ID')),
            ],
            rows: [
              for (final asset in assets)
                DataRow(
                  cells: [
                    DataCell(Text(asset.assetTag)),
                    DataCell(Text(asset.name)),
                    DataCell(Text(asset.category)),
                    DataCell(Text(asset.location)),
                    DataCell(Text(asset.value)),
                    DataCell(_AssetStatusChip(status: asset.status)),
                    DataCell(Text(asset.financeAssetId)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});

  final InventoryAsset asset;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Asset ${asset.assetTag}, ${asset.name}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${asset.assetTag} — ${asset.name}', style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text('${asset.category} · ${asset.location}', style: text.bodyMedium),
              Text('${asset.value} · ${asset.financeAssetId}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              _AssetStatusChip(status: asset.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetStatusChip extends StatelessWidget {
  const _AssetStatusChip({required this.status});

  final InventoryAssetStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      InventoryAssetStatus.available => ('Available', KpiAccent.success),
      InventoryAssetStatus.allocated => ('Allocated', KpiAccent.primary),
      InventoryAssetStatus.maintenance => ('Maintenance', KpiAccent.warning),
      InventoryAssetStatus.retired => ('Retired', KpiAccent.neutral),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Asset status: $label',
    );
  }
}
