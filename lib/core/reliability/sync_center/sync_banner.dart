import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reliability_providers.dart';
import 'sync_summary.dart';

/// A slim, unobtrusive banner shown ONLY when offline or when writes are
/// waiting/conflicted (refinement R3). Tapping opens the Sync Center.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, this.onOpenSyncCenter});

  final VoidCallback? onOpenSyncCenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncSummary s = ref.watch(syncCenterControllerProvider).summary;
    if (!s.shouldShowBanner) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final bool conflicts = s.hasConflicts;
    final Color bg = conflicts
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final Color fg = conflicts
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    final IconData icon = !s.online
        ? Icons.cloud_off
        : conflicts
            ? Icons.error_outline
            : Icons.sync;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onOpenSyncCenter,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _message(s),
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ),
              if (onOpenSyncCenter != null)
                Text('Details',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  String _message(SyncSummary s) {
    if (s.hasConflicts) {
      return '${s.conflicts} item(s) need your attention to sync';
    }
    if (!s.online) {
      return s.hasOutstanding
          ? "You're offline — ${s.outstanding} change(s) will sync when you reconnect"
          : "You're offline — your work is being saved on this device";
    }
    return 'Syncing ${s.outstanding} change(s)…';
  }
}
