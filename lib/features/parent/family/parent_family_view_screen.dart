import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../auth/auth_models.dart';
import '../../auth/auth_provider.dart';
import '../actions/parent_actions_provider.dart';
import '../parent_active_child_provider.dart';

/// PAR-D2 — a consolidated "all my children" family view for multi-child
/// parents: a totals header + one snapshot card per linked child.
///
/// Own-child scoped by construction: the children come ONLY from the auth
/// session's linked children (the JWT `child_ids`), never a client-supplied
/// list. Tapping a child switches the active child and returns to their
/// dashboard, so every per-child module reloads for that child.
class ParentFamilyViewScreen extends ConsumerWidget {
  const ParentFamilyViewScreen({
    super.key,
    this.onChildSelected,
  });

  /// Invoked after the active child is switched (e.g. to pop / navigate home).
  final VoidCallback? onChildSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final children = auth.linkedChildren;
    final activeChild = ref.watch(parentActiveChildProvider);
    // The action list is scoped to the ACTIVE child; surface its count against
    // that child's card (per-child on-demand loading avoids N concurrent
    // fetches for every sibling).
    final activeActions = ref.watch(parentActiveChildActionsProvider);

    return Scaffold(
      key: QaTestKeys.parentFamilyViewScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: const AksharaAppBar(
        titleText: 'My Children',
        subtitle: 'Family overview',
        showAi: false,
      ),
      // DS V2 P4 — premium persona canvas behind the family view content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: children.isEmpty
            ? const AksharaEmptyState(
                message: 'No children are linked to your account yet.',
                icon: Icons.family_restroom_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                children: [
                  _FamilyTotals(childCount: children.length),
                  const SizedBox(height: AksharaSpacing.s4),
                  for (final child in children) ...[
                    _ChildSnapshotCard(
                      child: child,
                      isActive: child.id == activeChild?.id,
                      actionCount: child.id == activeChild?.id
                          ? activeActions.length
                          : null,
                      onTap: () async {
                        await selectParentActiveChild(ref, child);
                        onChildSelected?.call();
                      },
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                  ],
                ],
              ),
      ),
    );
  }
}

class _FamilyTotals extends StatelessWidget {
  const _FamilyTotals({required this.childCount});

  final int childCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: AksharaKpiCard(
        value: '$childCount',
        subtitle: childCount == 1 ? 'Child' : 'Children',
        accent: KpiAccent.primary,
        icon: Icons.family_restroom_outlined,
      ),
    );
  }
}

class _ChildSnapshotCard extends StatelessWidget {
  const _ChildSnapshotCard({
    required this.child,
    required this.isActive,
    required this.actionCount,
    required this.onTap,
  });

  final LinkedChild child;
  final bool isActive;
  final int? actionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return AksharaSurfaceCard(
      key: QaTestKeys.parentFamilyChildCard(child.id),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Text(
              child.name.isEmpty ? '?' : child.name.characters.first,
              style:
                  text.titleMedium.copyWith(color: colors.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        child.name.isEmpty ? 'Student' : child.name,
                        style: text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AksharaSpacing.s2),
                      _ActiveBadge(),
                    ],
                  ],
                ),
                if (child.classLabel.isNotEmpty)
                  Text(
                    child.classLabel,
                    style:
                        text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                if (actionCount != null)
                  Text(
                    actionCount == 0
                        ? 'Nothing needs your action'
                        : '$actionCount item${actionCount == 1 ? '' : 's'} need your action',
                    style: text.bodySmall.copyWith(
                      color: actionCount == 0
                          ? colors.onSurfaceVariant
                          : colors.error,
                    ),
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

class _ActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
      ),
      child: Text(
        'Active',
        style: text.labelSmall.copyWith(color: colors.onPrimaryContainer),
      ),
    );
  }
}
