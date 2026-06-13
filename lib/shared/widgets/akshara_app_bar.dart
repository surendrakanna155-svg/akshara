import 'package:flutter/material.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Child selector chip used as the parent dashboard app bar title.
class AksharaChildSelectorChip extends StatelessWidget {
  const AksharaChildSelectorChip({
    super.key,
    required this.name,
    required this.classLabel,
    this.onTap,
  });

  final String name;
  final String classLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: 'Selected child $name, class $classLabel. Tap to switch child.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaSpacing.s12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AksharaSpacing.minTouchTarget,
            maxWidth: 220,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: text.labelMedium.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: text.bodyMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Class $classLabel',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s1),
              Icon(
                Icons.expand_more,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared mobile app bar for Akshara ERP feature screens.
class AksharaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AksharaAppBar({
    super.key,
    this.title,
    this.titleText,
    this.subtitle,
    this.unreadNotifications = 0,
    this.showAi = false,
    this.showProfile = false,
    this.showReceiptHistory = false,
    this.onAiTap,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onReceiptHistoryTap,
    this.trailingPadding = false,
    this.additionalActions = const [],
    this.titleTrailing,
    this.profileSemanticLabel = 'Parent profile',
    this.aiTooltip = 'AI Copilot',
    this.capNotificationBadgeAt99 = false,
  }) : assert(
          title != null || titleText != null,
          'Provide title widget or titleText',
        );

  final Widget? title;
  final String? titleText;
  final String? subtitle;
  final int unreadNotifications;
  final bool showAi;
  final bool showProfile;
  final bool showReceiptHistory;
  final VoidCallback? onAiTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onReceiptHistoryTap;
  final bool trailingPadding;
  final List<Widget> additionalActions;
  final Widget? titleTrailing;
  final String profileSemanticLabel;
  final String aiTooltip;
  final bool capNotificationBadgeAt99;

  @override
  Size get preferredSize =>
      const Size.fromHeight(AksharaSpacing.appBarHeightMobile);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return AppBar(
      toolbarHeight: AksharaSpacing.appBarHeightMobile,
      titleSpacing: AksharaSpacing.s4,
      title: title ??
          (titleTrailing != null
              ? Row(
                  children: [
                    Flexible(
                      child: Text(
                        titleText!,
                        style: text.titleLarge.copyWith(color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Flexible(child: titleTrailing!),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText!,
                      style: text.titleLarge.copyWith(color: colors.onSurface),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                )),
      actions: [
        ...additionalActions,
        if (showAi)
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: aiTooltip,
            onPressed: onAiTap,
          ),
        IconButton(
          icon: Badge(
            isLabelVisible: unreadNotifications > 0,
            label: Text(
              capNotificationBadgeAt99 && unreadNotifications > 99
                  ? '99+'
                  : '$unreadNotifications',
            ),
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: 'Notifications',
          onPressed: onNotificationsTap,
        ),
        if (showReceiptHistory)
          IconButton(
            key: QaTestKeys.receiptHistoryButton,
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Payment history',
            onPressed: onReceiptHistoryTap,
          ),
        if (showProfile)
          Padding(
            padding: const EdgeInsets.only(right: AksharaSpacing.s4),
            child: Semantics(
              button: true,
              label: profileSemanticLabel,
              child: InkWell(
                key: QaTestKeys.profileButton,
                onTap: onProfileTap,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        if (trailingPadding) const SizedBox(width: AksharaSpacing.s2),
      ],
    );
  }
}
