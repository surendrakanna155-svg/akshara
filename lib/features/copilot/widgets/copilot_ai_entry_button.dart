import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../dock/copilot_dock_provider.dart';

typedef CopilotAiEntryTap = void Function(BuildContext context, WidgetRef ref);
typedef CopilotAiEntryLongPress = void Function(
  BuildContext context,
  WidgetRef ref,
  Offset globalPosition,
);

/// Shared AI entry control — tap opens assistant, long-press shows quick actions.
class CopilotAiEntryButton extends ConsumerWidget {
  const CopilotAiEntryButton({
    super.key,
    required this.onTap,
    required this.onLongPress,
    this.size = 56,
    this.fabStyle = false,
  });

  final CopilotAiEntryTap onTap;
  final CopilotAiEntryLongPress onLongPress;
  final double size;
  final bool fabStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = copilotDockPersona(ref);
    final colors = context.colors;

    final child = Material(
      key: QaTestKeys.copilotAiEntryButton,
      color: fabStyle ? colors.primaryContainer : colors.primary,
      elevation: fabStyle ? 6 : 0,
      shape: fabStyle
          ? const CircleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(AksharaSpacing.s3)),
      child: InkWell(
        onTap: () => onTap(context, ref),
        onLongPress: () {
          final box = context.findRenderObject() as RenderBox?;
          final position = box?.localToGlobal(Offset.zero) ?? Offset.zero;
          onLongPress(context, ref, position);
        },
        customBorder: fabStyle
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(AksharaSpacing.s3)),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            copilotDockIconForPersona(persona),
            color: fabStyle ? colors.onPrimaryContainer : colors.onPrimary,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'AI assistant, ${persona.label}',
      child: child,
    );
  }
}
