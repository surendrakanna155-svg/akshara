import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../transport_models.dart';
import '../transport_navigation.dart';
import 'transport_sub_nav.dart';

class TransportModuleScaffold extends StatelessWidget {
  const TransportModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
  });

  final TransportScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: transportBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.transport,
        watermark: AksharaWatermarkMotif.busRoute,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            TransportSubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
            body,
          ],
        ),
      ),
    );
  }
}
