import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../parent_active_child_provider.dart';
import 'parent_actions_provider.dart';

/// PAR-D4 — a consolidated "what needs my action" inbox for the active child:
/// fees + PTM + forms + homework + exams, aggregated from REAL module data and
/// ordered fees/PTM first. Each row deep-links to the relevant screen.
///
/// Own-child scoped: every underlying provider is scoped to the active child
/// (the JWT `child_ids` path); nothing here can surface another child's data.
class ParentActionInboxScreen extends ConsumerWidget {
  const ParentActionInboxScreen({
    super.key,
    required this.onActionTap,
    this.onNotificationsTap,
  });

  /// Receives a dashboard navigation action id (e.g. 'fees', 'ptm').
  final void Function(String actionId) onActionTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(parentActiveChildProvider);
    final actions = ref.watch(parentActiveChildActionsProvider);

    return Scaffold(
      key: QaTestKeys.parentActionInboxScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Action Needed',
        subtitle: child?.name ?? 'Your child',
        showAi: false,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the action inbox content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: actions.isEmpty
            ? const AksharaEmptyState(
                message: 'You are all caught up. Nothing needs your action.',
                icon: Icons.task_alt_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                itemCount: actions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AksharaSpacing.s3),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _ActionInboxRow(
                    action: action,
                    onTap: () => onActionTap(action.kind.navigationActionId),
                  );
                },
              ),
      ),
    );
  }
}

class _ActionInboxRow extends StatelessWidget {
  const _ActionInboxRow({
    required this.action,
    required this.onTap,
  });

  final ParentActionItem action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return AksharaSurfaceCard(
      key: QaTestKeys.parentActionInboxItem(action.id),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AksharaSpacing.s3),
            ),
            child: Icon(action.kind.icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: text.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                if (action.detail != null)
                  Text(
                    action.detail!,
                    style:
                        text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
