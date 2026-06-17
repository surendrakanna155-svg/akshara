import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../management_models.dart';
import '../management_navigation.dart';
import 'management_sub_nav.dart';

class ManagementModuleScaffold extends StatelessWidget {
  const ManagementModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
  });

  final ManagementScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: managementBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.management,
        watermark: AksharaWatermarkMotif.chartTrend,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            ManagementSubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
            body,
          ],
        ),
      ),
    );
  }
}
