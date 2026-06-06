import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import '../sis_models.dart';
import '../sis_navigation.dart';
import 'sis_sub_nav.dart';

class SisModuleScaffold extends StatelessWidget {
  const SisModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.breadcrumbs,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
  });

  final SisScreen screen;
  final Widget body;
  final List<AdminBreadcrumb>? breadcrumbs;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: breadcrumbs ?? sisBreadcrumbs(screen),
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
          SisSubNav(current: screen),
          const SizedBox(height: AksharaSpacing.s4),
          body,
        ],
      ),
    );
  }
}
