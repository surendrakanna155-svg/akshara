import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_motion.dart';

/// Standard vertical gap between fields inside dialogs and sheets.
class AksharaDialogFieldGap extends SizedBox {
  const AksharaDialogFieldGap({super.key}) : super(height: AksharaSpacing.s3);
}

/// Premium dialog action row — cancel (text) + primary confirm.
class AksharaDialogActions extends StatelessWidget {
  const AksharaDialogActions({
    super.key,
    required this.onCancel,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.confirmKey,
    this.destructive = false,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;
  final Key? confirmKey;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: onCancel, child: Text(cancelLabel)),
        const SizedBox(width: AksharaSpacing.s2),
        FilledButton(
          key: confirmKey,
          onPressed: onConfirm,
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Executive alert / form dialog shell — uses global [DialogTheme] with M15 polish.
class AksharaAlertDialog extends StatelessWidget {
  const AksharaAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.icon,
    this.scrollable = false,
  });

  final String title;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    Widget? body = content;
    if (body != null && scrollable) {
      body = SingleChildScrollView(child: body);
    }

    return AlertDialog(
      icon: icon == null
          ? null
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.55),
                borderRadius: AksharaRadius.chip,
              ),
              child: Icon(icon, color: colors.primary, size: 24),
            ),
      title: Text(
        title,
        style: text.titleLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      content: body,
      actions: actions,
      actionsPadding: const EdgeInsets.fromLTRB(
        AksharaSpacing.s6,
        AksharaSpacing.s0,
        AksharaSpacing.s6,
        AksharaSpacing.s5,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AksharaSpacing.s6,
        AksharaSpacing.s2,
        AksharaSpacing.s6,
        AksharaSpacing.s4,
      ),
    );
  }
}

/// Bottom sheet title block with optional subtitle.
class AksharaBottomSheetHeader extends StatelessWidget {
  const AksharaBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(
      AksharaSpacing.s5,
      AksharaSpacing.s2,
      AksharaSpacing.s5,
      AksharaSpacing.s3,
    ),
  });

  final String title;
  final String? subtitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              subtitle!,
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Padded form body for dialogs — consistent field spacing.
class AksharaDialogFormBody extends StatelessWidget {
  const AksharaDialogFormBody({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const AksharaDialogFieldGap(),
        ],
      ],
    );
  }
}

/// Shows a premium confirm dialog; returns true when confirmed.
Future<bool> showAksharaConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData? icon,
  bool destructive = false,
  Key? confirmKey,
}) async {
  final result = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      icon: icon ?? (destructive ? Icons.warning_amber_rounded : null),
      title: title,
      content: Text(message, style: context.aksharaText.bodyLarge),
      actions: [
        AksharaDialogActions(
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          confirmKey: confirmKey,
          destructive: destructive,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
