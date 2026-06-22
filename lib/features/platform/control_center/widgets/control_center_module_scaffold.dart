import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../../shared/widgets/akshara_warning_banner.dart';
import '../../../../theme/mesh_background.dart';
import '../../../../theme/spacing.dart';
import '../../../admin/admin_content_scaffold.dart';
import '../../../admin/admin_shell.dart';
import '../control_center_models.dart';
import '../control_center_navigation.dart';
import 'control_center_sub_nav.dart';

class ControlCenterModuleScaffold extends StatelessWidget {
  const ControlCenterModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
    this.showPiiBanner = true,
  });

  final ControlCenterScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;
  final bool showPiiBanner;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: controlCenterBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.admin,
        watermark: AksharaWatermarkMotif.sparkles,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            ControlCenterSubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
            if (showPiiBanner) ...[
              const AksharaWarningBanner(
                message: kControlCenterPiiBannerMessage,
                height: 40,
                compactMessage: true,
                semanticLabel: 'Platform privacy notice',
              ),
              const SizedBox(height: AksharaSpacing.s4),
            ],
            body,
          ],
        ),
      ),
    );
  }
}
