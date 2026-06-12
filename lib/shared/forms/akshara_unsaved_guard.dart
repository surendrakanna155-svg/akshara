import 'package:flutter/material.dart';

/// Blocks back navigation when [hasUnsavedChanges] and prompts to discard.
class AksharaUnsavedChangesGuard extends StatelessWidget {
  const AksharaUnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.message = 'You have unsaved changes. Discard them?',
  });

  final bool hasUnsavedChanges;
  final Widget child;
  final String message;

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text(message),
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
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !hasUnsavedChanges) return;
        final discard = await _confirmDiscard(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
