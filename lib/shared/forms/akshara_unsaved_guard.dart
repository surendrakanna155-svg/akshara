import 'package:flutter/material.dart';

import 'web_unsaved_guard.dart';

/// Blocks back navigation when [hasUnsavedChanges] and prompts to discard.
///
/// RT-30 — in addition to the in-app `PopScope` (Android back, in-app/back-button
/// navigation, and Flutter-web router pops), this also arms the browser's native
/// `beforeunload` confirmation on web while there are unsaved changes, so a tab
/// close or hard refresh cannot silently discard the user's work.
class AksharaUnsavedChangesGuard extends StatefulWidget {
  const AksharaUnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.message = 'You have unsaved changes. Discard them?',
  });

  final bool hasUnsavedChanges;
  final Widget child;
  final String message;

  @override
  State<AksharaUnsavedChangesGuard> createState() =>
      _AksharaUnsavedChangesGuardState();
}

class _AksharaUnsavedChangesGuardState
    extends State<AksharaUnsavedChangesGuard> {
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AksharaUnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasUnsavedChanges != widget.hasUnsavedChanges) {
      _sync();
    }
  }

  /// Keeps the web `beforeunload` counter in step with this guard's dirty state.
  void _sync() {
    if (widget.hasUnsavedChanges && !_registered) {
      _registered = true;
      setWebUnloadGuardActive(true);
    } else if (!widget.hasUnsavedChanges && _registered) {
      _registered = false;
      setWebUnloadGuardActive(false);
    }
  }

  @override
  void dispose() {
    if (_registered) {
      _registered = false;
      setWebUnloadGuardActive(false);
    }
    super.dispose();
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text(widget.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !widget.hasUnsavedChanges) return;
        final discard = await _confirmDiscard(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: widget.child,
    );
  }
}
