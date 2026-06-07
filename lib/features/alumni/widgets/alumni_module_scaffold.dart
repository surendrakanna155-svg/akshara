import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import '../alumni_models.dart';
import '../alumni_navigation.dart';
import 'alumni_sub_nav.dart';

class AlumniModuleScaffold extends StatelessWidget {
  const AlumniModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.breadcrumbs,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
    this.showSubNav = true,
  });

  final AlumniScreen screen;
  final Widget body;
  final List<AdminBreadcrumb>? breadcrumbs;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;
  final bool showSubNav;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: breadcrumbs ?? alumniBreadcrumbs(screen),
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
          if (showSubNav) ...[
            AlumniSubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
          ],
          body,
        ],
      ),
    );
  }
}
