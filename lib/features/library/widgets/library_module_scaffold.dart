import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_shell.dart';
import '../../admin/models/admin_nav_models.dart';
import '../library_models.dart';
import '../library_navigation.dart';
import 'library_sub_nav.dart';

class LibraryModuleScaffold extends StatelessWidget {
  const LibraryModuleScaffold({
    super.key,
    required this.screen,
    required this.body,
    this.showFilterBar = true,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
    this.breadcrumbsOverride,
  });

  final LibraryScreen screen;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;

  /// LIB-1 — a secondary screen (e.g. Overdue loans) that is not a sub-nav tab
  /// can supply its own breadcrumb trail; the sub-nav still highlights [screen].
  final List<AdminBreadcrumb>? breadcrumbsOverride;

  @override
  Widget build(BuildContext context) {
    return AdminContentScaffold(
      breadcrumbs: breadcrumbsOverride ?? libraryBreadcrumbs(screen),
      showFilterBar: showFilterBar,
      filters: filters,
      selectedFilterIndex: selectedFilterIndex,
      onFilterSelected: onFilterSelected,
      filterTrailing: filterTrailing,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.neutral,
        watermark: AksharaWatermarkMotif.bookStack,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s4),
            LibrarySubNav(current: screen),
            const SizedBox(height: AksharaSpacing.s4),
            body,
          ],
        ),
      ),
    );
  }
}
