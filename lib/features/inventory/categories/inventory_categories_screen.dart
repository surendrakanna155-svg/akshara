import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../widgets/inventory_module_scaffold.dart';

/// INV-03 — Categories.
class InventoryCategoriesScreen extends ConsumerWidget {
  const InventoryCategoriesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Equipment',
    'Furniture',
    'Electronics',
    'Consumables',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryCategoriesLoadingProvider);
    final isError = ref.watch(inventoryCategoriesErrorProvider);
    final isEmpty = ref.watch(inventoryCategoriesEmptyProvider);
    final categories = ref.watch(inventoryFilteredCategoriesProvider);
    final filterIndex = ref.watch(inventoryCategoriesFilterProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.categories,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryCategoriesFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        categories: categories,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<InventoryCategory> categories,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading categories'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load categories.');
    }

    if (isEmpty || categories.isEmpty) {
      return const AksharaEmptyState(
        message: 'No categories match the selected filters.',
        icon: Icons.category_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Category catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        _CategoryTable(categories: categories),
      ],
    );
  }
}

class _CategoryTable extends StatelessWidget {
  const _CategoryTable({required this.categories});

  final List<InventoryCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final category in categories) ...[
            _CategoryCard(category: category),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Category catalog, ${categories.length} categories',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Assets')),
              DataColumn(label: Text('Total value')),
              DataColumn(label: Text('Depreciation')),
              DataColumn(label: Text('Department')),
            ],
            rows: [
              for (final category in categories)
                DataRow(
                  cells: [
                    DataCell(Text(category.name)),
                    DataCell(Text(_typeLabel(category.type))),
                    DataCell(Text('${category.assetCount}')),
                    DataCell(Text(category.totalValue)),
                    DataCell(Text(category.depreciationRate)),
                    DataCell(Text(category.responsibleDept)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(InventoryCategoryType type) => switch (type) {
        InventoryCategoryType.equipment => 'Equipment',
        InventoryCategoryType.furniture => 'Furniture',
        InventoryCategoryType.electronics => 'Electronics',
        InventoryCategoryType.consumable => 'Consumable',
        InventoryCategoryType.lab => 'Lab',
        InventoryCategoryType.sports => 'Sports',
      };
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final InventoryCategory category;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Category ${category.name}, ${category.assetCount} assets',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.name, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(category.description, style: text.bodyMedium),
              Text(
                '${category.assetCount} assets · ${category.totalValue} · ${category.depreciationRate}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
