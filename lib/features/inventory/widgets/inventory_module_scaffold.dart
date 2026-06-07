import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../inventory_models.dart';
import '../inventory_navigation.dart';
import 'inventory_sub_nav.dart';

class InventoryModuleScaffold extends StatelessWidget {
  const InventoryModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
  });

  final InventoryScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: inventoryBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AksharaSpacing.s4),
          InventorySubNav(current: screen),
          const SizedBox(height: AksharaSpacing.s4),
          body,
        ],
      ),
    );
  }
}
