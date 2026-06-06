import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'notifications_models.dart';
import 'notifications_provider.dart';

/// Parent notification inbox — NT-01 mobile pattern.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;
  static const double _rowHeight = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(notificationFilterProvider);
    ref.watch(notificationsProvider);
    final items = ref.read(notificationsProvider.notifier).filtered(filter);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: items.isEmpty
                ? null
                : () => ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= _tabletBreakpoint;
          final horizontalPadding = isTablet
              ? AksharaSpacing.tabletMargin
              : AksharaSpacing.mobileMargin;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? _tabletMaxContentWidth : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: AksharaSpacing.s2,
                      ),
                      children: [
                        for (final chip in NotificationFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AksharaSpacing.s2,
                            ),
                            child: FilterChip(
                              label: Text(chip.label),
                              selected: filter == chip,
                              onSelected: (_) => ref
                                  .read(notificationFilterProvider.notifier)
                                  .state = chip,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(notificationsProvider.notifier).refresh(),
                      child: items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: constraints.maxHeight * 0.5,
                                  child: _EmptyInbox(),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                AksharaSpacing.s2,
                                horizontalPadding,
                                AksharaSpacing.s6,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AksharaSpacing.s2),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _NotificationRow(
                                  notification: item,
                                  onTap: () {
                                    ref
                                        .read(notificationsProvider.notifier)
                                        .markRead(item.id);
                                  },
                                  onDismissed: (action) {
                                    final notifier =
                                        ref.read(notificationsProvider.notifier);
                                    if (action == _DismissAction.read) {
                                      notifier.markRead(item.id);
                                    } else {
                                      notifier.archive(item.id);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _DismissAction { read, archive }

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final void Function(_DismissAction action) onDismissed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final text = context.aksharaText;
    final categoryColor = _categoryColor(context, notification.category);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onDismissed(_DismissAction.read);
        } else {
          onDismissed(_DismissAction.archive);
        }
        return true;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AksharaSpacing.s4),
        decoration: BoxDecoration(
          color: ext.successContainer,
          borderRadius: AksharaRadius.card,
        ),
        child: Icon(Icons.done, color: ext.success),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AksharaSpacing.s4),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: AksharaRadius.card,
        ),
        child: Icon(Icons.archive_outlined, color: colors.error),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: AksharaRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: NotificationsScreen._rowHeight,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: notification.isRead
                      ? Colors.transparent
                      : colors.primary,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s3,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.category.icon,
                    size: 22,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: text.bodyMedium.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (notification.isUrgent)
                            Container(
                              margin: const EdgeInsets.only(
                                left: AksharaSpacing.s2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AksharaSpacing.s2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: AksharaRadius.chip,
                              ),
                              child: Text(
                                'Urgent',
                                style: text.labelSmall.copyWith(
                                  color: colors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.preview,
                        style: text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.childContext != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          notification.childContext!,
                          style: text.labelSmall.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTimestamp(notification.timestamp),
                      style: text.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(BuildContext context, NotificationCategory category) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (category) {
      NotificationCategory.fee => ext.warning,
      NotificationCategory.attendance => colors.error,
      NotificationCategory.approval => ext.success,
      _ => colors.primary,
    };
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Text(
              "You're all caught up",
              style: text.titleMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'New school alerts will appear here.',
              style: text.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${timestamp.day} ${months[timestamp.month - 1]}';
}
