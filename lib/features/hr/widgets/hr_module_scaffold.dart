import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import '../hr_models.dart';
import '../hr_navigation.dart';
import 'hr_sub_nav.dart';

class HrModuleScaffold extends StatelessWidget {
  const HrModuleScaffold({
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

  final HrScreen screen;
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
      breadcrumbs: breadcrumbs ?? hrBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.neutral,
        watermark: AksharaWatermarkMotif.graduationCap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            if (showSubNav) ...[
              HrSubNav(current: screen),
              const SizedBox(height: AksharaSpacing.s4),
            ],
            body,
          ],
        ),
      ),
    );
  }
}
