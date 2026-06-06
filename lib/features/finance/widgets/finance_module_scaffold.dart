import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../finance_models.dart';
import '../finance_navigation.dart';
import 'finance_sub_nav.dart';

/// Finance wrapper over [AdminContentScaffold] with sub-nav and breadcrumbs.
class FinanceModuleScaffold extends StatelessWidget {
  const FinanceModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
  });

  final FinanceScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: financeBreadcrumbs(screen),
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
          FinanceSubNav(current: screen),
          const SizedBox(height: AksharaSpacing.s4),
          body,
        ],
      ),
    );
  }
}
