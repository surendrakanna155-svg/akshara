import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/mutation_envelope.dart';
import '../model/reliability_enums.dart';
import '../reliability_providers.dart';
import 'sync_center_controller.dart';
import 'sync_summary.dart';

/// The Sync Center (refinement R3): pending counter, manual retry, detailed sync
/// history, and explicit resolution for high-risk conflicts.
class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncCenterController controller =
        ref.watch(syncCenterControllerProvider);
    final SyncSummary s = controller.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Center'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(summary: s),
          if (s.outstanding > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: controller.retryAll,
                icon: const Icon(Icons.sync),
                label: const Text('Retry now'),
              ),
            ),
          const Divider(height: 24),
          Expanded(
            child: s.history.isEmpty
                ? const Center(child: Text('Nothing to sync.'))
                : ListView.separated(
                    itemCount: s.history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int i) =>
                        _OperationTile(op: s.history[i], controller: controller),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});
  final SyncSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Icon(summary.online ? Icons.cloud_done : Icons.cloud_off),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(summary.online ? 'Online' : 'Offline',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  summary.hasOutstanding
                      ? '${summary.pending} pending · ${summary.inFlight} syncing · '
                          '${summary.conflicts} conflicts · ${summary.failed} failed'
                      : 'All changes synced',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.op, required this.controller});
  final MutationEnvelope op;
  final SyncCenterController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _StatusIcon(status: op.status),
      title: Text(op.request.type),
      subtitle: Text(
        '${op.request.method} ${op.request.path}'
        '${op.lastError != null ? '\n${op.lastError}' : ''}',
      ),
      isThreeLine: op.lastError != null,
      trailing: op.status == SyncStatus.conflict
          ? Wrap(
              spacing: 4,
              children: <Widget>[
                TextButton(
                  onPressed: () =>
                      controller.resolveConflict(op.id, keepClient: true),
                  child: const Text('Keep mine'),
                ),
                TextButton(
                  onPressed: () =>
                      controller.resolveConflict(op.id, keepClient: false),
                  child: const Text('Use server'),
                ),
              ],
            )
          : null,
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    switch (status) {
      case SyncStatus.confirmed:
        return Icon(Icons.check_circle, color: c.primary);
      case SyncStatus.pending:
        return const Icon(Icons.schedule);
      case SyncStatus.inFlight:
        return const Icon(Icons.sync);
      case SyncStatus.conflict:
        return Icon(Icons.error_outline, color: c.error);
      case SyncStatus.failed:
        return Icon(Icons.cancel, color: c.error);
    }
  }
}
