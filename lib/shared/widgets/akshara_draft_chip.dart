import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_dialog.dart';

/// B1 (feel & trust) — a small "Draft saved" pill for forms that autosave an
/// in-progress draft (REL-3), so the user can SEE that their work is safe even
/// before they submit. Purely presentational; the screen decides when to show it
/// (e.g. once its [DraftController] has persisted a snapshot).
class AksharaDraftChip extends StatelessWidget {
  const AksharaDraftChip({
    super.key,
    this.label = 'Draft saved',
    this.icon = Icons.edit_note_outlined,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s2,
          vertical: AksharaSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AksharaRadius.full),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: colors.onSurfaceVariant),
            const SizedBox(width: AksharaSpacing.s1),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// B1 (feel & trust) — guards back-navigation while a form holds unsaved edits.
///
/// A thin wrapper over [PopScope]: while [hasUnsavedChanges] is true a back
/// gesture / button is intercepted and the app's confirm dialog asks before the
/// route is popped; on confirm [onDiscard] runs and the route pops. When there
/// are no unsaved changes, back works normally.
class AksharaUnsavedChangesScope extends StatelessWidget {
  const AksharaUnsavedChangesScope({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.title = 'Discard changes?',
    this.message = 'You have unsaved changes. Leave without saving?',
    this.confirmLabel = 'Discard',
    this.cancelLabel = 'Keep editing',
    this.onDiscard,
  });

  final bool hasUnsavedChanges;
  final Widget child;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await showAksharaConfirmDialog(
          context,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          destructive: true,
        );
        if (discard) {
          onDiscard?.call();
          navigator.pop(result);
        }
      },
      child: child,
    );
  }
}
