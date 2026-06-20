import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../core/workspace/workspace.dart';
import '../../core/workspace/workspace_providers.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Premium "switch hats" control. Shown only when a user holds more than one
/// workspace (e.g. Teacher + Inventory Manager). Selecting a workspace activates
/// it and lands on its home — the USER → ROLE → WORKSPACE → TASK switcher.
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(userWorkspacesProvider);
    if (workspaces.length < 2) return const SizedBox.shrink();

    final active = ref.watch(activeWorkspaceProvider);
    final text = context.aksharaText;
    final colors = context.colors;

    return Column(
      key: QaTestKeys.workspaceSwitcher,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your workspaces',
          style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: AksharaSpacing.s3),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final workspace in workspaces)
                Padding(
                  padding: const EdgeInsets.only(right: AksharaSpacing.s3),
                  child: _WorkspaceChip(
                    workspace: workspace,
                    selected: workspace.id == active?.id,
                    onTap: () {
                      ref.read(activeWorkspaceIdProvider.notifier).state =
                          workspace.id;
                      context.go(workspace.homeRoute);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact app-bar switcher — lives in every shell's chrome so a multi-hat user
/// can change workspace from ANY screen (not just the Admin Hub). Auto-hides for
/// single-workspace users, so single-role personas never see it.
class WorkspaceSwitcherButton extends ConsumerWidget {
  const WorkspaceSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(userWorkspacesProvider);
    if (workspaces.length < 2) return const SizedBox.shrink();

    final active = ref.watch(activeWorkspaceProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(right: AksharaSpacing.s1),
      child: Material(
        key: QaTestKeys.workspaceSwitcherButton,
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AksharaSpacing.s5),
        child: InkWell(
          borderRadius: BorderRadius.circular(AksharaSpacing.s5),
          onTap: () => _openPicker(context, ref, workspaces, active?.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s3,
              vertical: AksharaSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active?.icon ?? Icons.grid_view_rounded,
                    size: 18, color: colors.onPrimaryContainer),
                const SizedBox(width: AksharaSpacing.s2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    active?.shortTitle ?? 'Workspace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.expand_more,
                    size: 18, color: colors.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPicker(
    BuildContext context,
    WidgetRef ref,
    List<Workspace> workspaces,
    WorkspaceId? activeId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        final text = sheetContext.aksharaText;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AksharaSpacing.s5,
                  AksharaSpacing.s2,
                  AksharaSpacing.s5,
                  AksharaSpacing.s3,
                ),
                child: Text('Switch workspace', style: text.titleMedium),
              ),
              for (final workspace in workspaces)
                ListTile(
                  key: QaTestKeys.workspaceSwitcherSheetItem(workspace.shortTitle),
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    child: Icon(workspace.icon,
                        color: colors.onPrimaryContainer, size: 20),
                  ),
                  title: Text(workspace.title),
                  trailing: workspace.id == activeId
                      ? Icon(Icons.check_circle, color: colors.primary)
                      : null,
                  onTap: () {
                    ref.read(activeWorkspaceIdProvider.notifier).state =
                        workspace.id;
                    Navigator.of(sheetContext).pop();
                    context.go(workspace.homeRoute);
                  },
                ),
              const SizedBox(height: AksharaSpacing.s4),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({
    required this.workspace,
    required this.selected,
    required this.onTap,
  });

  final Workspace workspace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final gradient = LinearGradient(
      colors: [colors.primary, colors.tertiary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Material(
      key: QaTestKeys.workspaceSwitcherChip(workspace.shortTitle),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaSpacing.s5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          ),
          decoration: BoxDecoration(
            gradient: selected ? gradient : null,
            color: selected ? null : colors.surface,
            borderRadius: BorderRadius.circular(AksharaSpacing.s5),
            border: Border.all(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                workspace.icon,
                size: 18,
                color: selected ? colors.onPrimary : colors.primary,
              ),
              const SizedBox(width: AksharaSpacing.s2),
              Text(
                workspace.shortTitle,
                style: text.labelLarge?.copyWith(
                  color: selected ? colors.onPrimary : colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
