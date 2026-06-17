import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../director_models.dart';
import '../director_navigation.dart';
import 'director_sub_nav.dart';

class DirectorModuleScaffold extends StatelessWidget {
  const DirectorModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
    this.showFilterBar = true,
  });

  final DirectorScreen screen;
  final Widget body;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;
  final bool showFilterBar;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: directorBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.director,
        watermark: AksharaWatermarkMotif.shield,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            DirectorSubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaWarningBanner(
              message: kDirectorPrivacyBannerMessage,
              height: 40,
              compactMessage: true,
              semanticLabel: 'Director privacy notice',
            ),
            const SizedBox(height: AksharaSpacing.s4),
            body,
          ],
        ),
      ),
    );
  }
}
