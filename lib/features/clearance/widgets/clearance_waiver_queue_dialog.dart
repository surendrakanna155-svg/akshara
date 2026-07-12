import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme_extensions.dart';
import '../clearance_datasource.dart';
import '../clearance_models.dart';
import '../clearance_providers.dart';

/// SCE-1 slice 4 — the checker's dues-waiver approval queue. School-wide pending
/// waivers with Approve / Reject. The HOST shows it only to holders of
/// Permission.approveClearanceWaiver (the same permission the server enforces on
/// the list + decide). Separation of duties (a maker cannot approve their own)
/// is enforced server-side and surfaces as a typed rejection here.
class ClearanceWaiverQueueDialog extends ConsumerStatefulWidget {
  const ClearanceWaiverQueueDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const ClearanceWaiverQueueDialog(),
      );

  @override
  ConsumerState<ClearanceWaiverQueueDialog> createState() => _State();
}

class _State extends ConsumerState<ClearanceWaiverQueueDialog> {
  final Set<String> _deciding = {};

  Future<void> _decide(String waiverId, bool approve) async {
    setState(() => _deciding.add(waiverId));
    try {
      await ref.read(clearanceDataSourceProvider).decideWaiver(waiverId: waiverId, approve: approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Waiver approved.' : 'Waiver rejected.')),
      );
      setState(() => _deciding.remove(waiverId));
      ref.invalidate(pendingClearanceWaiversProvider);
    } on ClearanceWaiverRejected catch (e) {
      // Typed verdict (SoD / already-decided / active-exists): show it + refresh.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _deciding.remove(waiverId));
      ref.invalidate(pendingClearanceWaiversProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record the decision. Try again.')),
      );
      setState(() => _deciding.remove(waiverId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingClearanceWaiversProvider);
    final text = context.aksharaText;
    return AlertDialog(
      key: const Key('clearance-waiver-queue-dialog'),
      title: const Text('Clearance dues-waivers'),
      content: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Text('Unable to load pending waivers.', style: text.bodyMedium),
          data: (waivers) => waivers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No pending waivers.',
                    key: const Key('clearance-waiver-queue-empty'),
                    style: text.bodySmall,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final w in waivers) _WaiverCard(
                      waiver: w,
                      deciding: _deciding.contains(w.id),
                      onApprove: () => _decide(w.id, true),
                      onReject: () => _decide(w.id, false),
                    ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _WaiverCard extends StatelessWidget {
  const _WaiverCard({
    required this.waiver,
    required this.deciding,
    required this.onApprove,
    required this.onReject,
  });

  final ClearanceWaiver waiver;
  final bool deciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${waiver.amount.toStringAsFixed(0)} dues waiver', style: text.titleSmall),
            Text(waiver.reason, style: text.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  key: Key('clearance-waiver-approve-${waiver.id}'),
                  onPressed: deciding ? null : onApprove,
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: Key('clearance-waiver-reject-${waiver.id}'),
                  onPressed: deciding ? null : onReject,
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
