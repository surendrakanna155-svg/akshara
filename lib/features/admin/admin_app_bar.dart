import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_navigation.dart';
import '../../shared/widgets/akshara_glass_surface.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'admin_layout.dart';
import 'models/admin_nav_models.dart';

/// Web admin app bar with breadcrumbs, search, notifications, and AI placeholders.
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({
    super.key,
    required this.breadcrumbs,
    this.onMenuTap,
    this.unreadNotifications = 0,
    this.onSearchTap,
    this.onNotificationsTap,
    this.showAiCopilot = true,
    this.onAiCopilotTap,
    this.onProfileTap,
  });

  final List<AdminBreadcrumb> breadcrumbs;
  final VoidCallback? onMenuTap;
  final int unreadNotifications;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final bool showAiCopilot;
  final VoidCallback? onAiCopilotTap;
  final VoidCallback? onProfileTap;

  @override
  Size get preferredSize =>
      const Size.fromHeight(AksharaSpacing.appBarHeightWeb);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final isMobile = AdminLayout.isMobile(context);
    final isDesktop = AdminLayout.isDesktop(context);

    return AksharaGlassBar(
      height: AksharaSpacing.appBarHeightWeb,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile
                ? AksharaSpacing.mobileMargin
                : AksharaSpacing.desktopMargin,
          ),
          child: Row(
            children: [
                  if (isMobile)
                    AksharaAppBarIconButton(
                      key: QaTestKeys.erpMenuButton,
                      icon: Icons.menu,
                      tooltip: 'Open navigation',
                      onPressed: onMenuTap,
                    ),
                  if (isMobile) const SizedBox(width: AksharaSpacing.s2),
                  Expanded(
                    child: _AdminBreadcrumbs(
                      breadcrumbs: breadcrumbs,
                      textStyle: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      activeStyle: text.bodySmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: AksharaSpacing.s4),
                    AksharaNavSearchField(
                      hint: 'Search ERP…',
                      onTap: onSearchTap,
                    ),
                  ],
                  if (!isDesktop)
                    AksharaAppBarIconButton(
                      icon: Icons.search,
                      tooltip: 'Search',
                      onPressed: onSearchTap,
                    ),
                  const SizedBox(width: AksharaSpacing.s1),
                  AksharaAppBarIconButton(
                    icon: Icons.notifications_outlined,
                    tooltip: 'Notifications',
                    onPressed: onNotificationsTap,
                    child: Badge(
                      isLabelVisible: unreadNotifications > 0,
                      label: Text('$unreadNotifications'),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 22,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (showAiCopilot) ...[
                    const SizedBox(width: AksharaSpacing.s1),
                    AksharaAppBarIconButton(
                      key: QaTestKeys.erpCopilotButton,
                      icon: Icons.psychology_outlined,
                      tooltip: 'AI Copilot',
                      onPressed: onAiCopilotTap,
                    ),
                  ],
                  const SizedBox(width: AksharaSpacing.s2),
                  Semantics(
                    button: true,
                    label: 'Staff profile',
                    child: InkWell(
                      key: QaTestKeys.profileButton,
                      onTap: onProfileTap,
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.primaryContainer,
                        child: Icon(
                          Icons.person_outline,
                          size: 20,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBreadcrumbs extends StatelessWidget {
  const _AdminBreadcrumbs({
    required this.breadcrumbs,
    required this.textStyle,
    required this.activeStyle,
  });

  final List<AdminBreadcrumb> breadcrumbs;
  final TextStyle textStyle;
  final TextStyle activeStyle;

  @override
  Widget build(BuildContext context) {
    if (breadcrumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    for (var i = 0; i < breadcrumbs.length; i++) {
      final crumb = breadcrumbs[i];
      final isLast = i == breadcrumbs.length - 1;

      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s1),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }

      if (!isLast && crumb.route != null) {
        children.add(
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s2),
              minimumSize: const Size(0, AksharaSpacing.minTouchTarget),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context.go(crumb.route!),
            child: Text(crumb.label, style: textStyle),
          ),
        );
      } else {
        children.add(Text(crumb.label, style: isLast ? activeStyle : textStyle));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}
