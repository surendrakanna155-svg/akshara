import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';
import '../../theme/spacing.dart';
import 'admin_app_bar.dart';
import 'admin_filter_bar.dart';
import 'admin_layout.dart';
import 'models/admin_nav_models.dart';

/// Page scaffold for web ERP modules: app bar, optional filter bar, 1440-grid body.
class AdminContentScaffold extends StatelessWidget {
  const AdminContentScaffold({
    super.key,
    required this.breadcrumbs,
    required this.body,
    this.showFilterBar = false,
    this.filters,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.filterTrailing,
    this.onMenuTap,
    this.unreadNotifications = 0,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onAiCopilotTap,
    this.onProfileTap,
    this.bottomSpacing = AksharaSpacing.s8,
  });

  final List<AdminBreadcrumb> breadcrumbs;
  final Widget body;
  final bool showFilterBar;
  final List<String>? filters;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? filterTrailing;
  final VoidCallback? onMenuTap;
  final int unreadNotifications;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAiCopilotTap;
  final VoidCallback? onProfileTap;
  final double bottomSpacing;

  void _showPlaceholderSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminAppBar(
            breadcrumbs: breadcrumbs,
            onMenuTap: onMenuTap,
            unreadNotifications: unreadNotifications,
            onSearchTap: onSearchTap ??
                () => _showPlaceholderSnackBar(
                      context,
                      'Global search coming soon.',
                    ),
            onNotificationsTap: onNotificationsTap ??
                () => _showPlaceholderSnackBar(
                      context,
                      'Notifications coming soon.',
                    ),
            onAiCopilotTap: onAiCopilotTap ??
                () => context.go(RouteNames.copilot),
            onProfileTap: onProfileTap ??
                () => _showPlaceholderSnackBar(
                      context,
                      'Profile menu coming soon.',
                    ),
          ),
          if (showFilterBar)
            AdminFilterBar(
              filters: filters ?? const ['All', 'This period', 'Active'],
              selectedIndex: selectedFilterIndex,
              onFilterSelected: onFilterSelected,
              trailing: filterTrailing,
            ),
          Expanded(
            child: SingleChildScrollView(
              child: AdminLayout.constrainContent(
                context: context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    body,
                    SizedBox(height: bottomSpacing),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
