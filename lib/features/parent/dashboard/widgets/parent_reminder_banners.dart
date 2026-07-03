import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../actions/parent_actions_provider.dart';

/// PAR-5 — multi-type in-app reminder banners (fee due / exam / PTM / form /
/// homework) on the parent dashboard, derived from REAL module data. Banner
/// copy is resolved from the DETERMINISTIC content catalog in the parent's
/// language (NO LLM / free-text translate). Each banner deep-links to the
/// relevant screen via [onActionTap].
class ParentReminderBanners extends ConsumerWidget {
  const ParentReminderBanners({
    super.key,
    required this.onActionTap,
    this.maxBanners = 3,
  });

  /// Receives a dashboard navigation action id (e.g. 'fees', 'ptm').
  final void Function(String actionId) onActionTap;

  /// Cap so the dashboard is never flooded (fees + PTM are prioritised first).
  final int maxBanners;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(parentActiveChildActionsProvider);
    if (actions.isEmpty) return const SizedBox.shrink();

    final shown = actions.take(maxBanners).toList(growable: false);

    return Column(
      key: QaTestKeys.parentReminderBanners,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in shown) ...[
          _ReminderBanner(
            action: action,
            onTap: () => onActionTap(action.kind.navigationActionId),
          ),
          const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}

class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({
    required this.action,
    required this.onTap,
  });

  final ParentActionItem action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    final (bg, fg) = switch (action.kind) {
      ParentActionKind.fee => (colors.errorContainer, colors.onErrorContainer),
      ParentActionKind.ptm => (
          colors.primaryContainer,
          colors.onPrimaryContainer
        ),
      ParentActionKind.form => (ext.warningContainer, colors.onSurface),
      ParentActionKind.homework => (
          colors.secondaryContainer,
          colors.onSecondaryContainer
        ),
      ParentActionKind.exam => (ext.tertiaryContainer, colors.onSurface),
    };

    return Material(
      key: QaTestKeys.parentReminderBanner(action.kind.key),
      color: bg,
      borderRadius: AksharaRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          ),
          child: Row(
            children: [
              Icon(action.kind.icon, color: fg, size: 22),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: text.bodyMedium.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (action.detail != null)
                      Text(
                        action.detail!,
                        style: text.bodySmall.copyWith(color: fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
