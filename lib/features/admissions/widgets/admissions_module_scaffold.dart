import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../admissions_navigation.dart';
import 'admissions_sub_nav.dart';

/// Admissions wrapper over [AdminContentScaffold] with sub-nav and breadcrumbs.
class AdmissionsModuleScaffold extends StatelessWidget {
  const AdmissionsModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
    this.scrollableBody = true,
  });

  final AdmissionsScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;
  final bool scrollableBody;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: admissionsBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      scrollableBody: scrollableBody,
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.neutral,
        watermark: AksharaWatermarkMotif.graduationCap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            AdmissionsSubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
            if (scrollableBody) body else Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
