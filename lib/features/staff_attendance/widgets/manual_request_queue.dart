import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../manual_request_datasource.dart';
import '../staff_attendance_providers.dart';

/// P1-PROD-22 slice 4 — the approver's Manual Attendance Request queue. The
/// HOST decides visibility (only for holders of
/// `Permission.approveStaffAttendance` — the same supervisory permission the
/// server enforces on both the list read and the decide write). Approve
/// records the check-in server-side (method='manual', fully audited); reject
/// closes the request.
class ManualRequestQueue extends ConsumerStatefulWidget {
  const ManualRequestQueue({super.key});

  @override
  ConsumerState<ManualRequestQueue> createState() => _ManualRequestQueueState();
}

class _ManualRequestQueueState extends ConsumerState<ManualRequestQueue> {
  late Future<List<PendingManualRequest>> _pending;
  final Set<String> _deciding = {};

  @override
  void initState() {
    super.initState();
    _pending = _load();
  }

  Future<List<PendingManualRequest>> _load() =>
      ref.read(manualAttendanceRequestDataSourceProvider).pendingQueue();

  Future<void> _decide(String requestId, bool approve) async {
    setState(() => _deciding.add(requestId));
    try {
      await ref
          .read(manualAttendanceRequestDataSourceProvider)
          .decide(requestId: requestId, approve: approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Request approved.' : 'Request rejected.')),
      );
      setState(() {
        _deciding.remove(requestId);
        _pending = _load();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record the decision. Try again.')),
      );
      setState(() => _deciding.remove(requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      key: const Key('manual-request-queue'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Manual attendance requests'),
        FutureBuilder<List<PendingManualRequest>>(
          future: _pending,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s4),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
                child: Text(
                  'Unable to load pending requests.',
                  style: text.bodySmall,
                ),
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
                child: Text(
                  'No pending requests.',
                  key: const Key('manual-request-queue-empty'),
                  style: text.bodySmall,
                ),
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _RequestCard(
                    item: item,
                    deciding: _deciding.contains(item.id),
                    onApprove: () => _decide(item.id, true),
                    onReject: () => _decide(item.id, false),
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.deciding,
    required this.onApprove,
    required this.onReject,
  });

  final PendingManualRequest item;
  final bool deciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final eventLabel = item.eventType == 'check_out' ? 'Check out' : 'Check in';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.staffName.isEmpty ? 'Staff member' : item.staffName,
              style: text.titleSmall,
            ),
            Text('$eventLabel — ${item.reason}', style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s2),
            Row(
              children: [
                FilledButton.tonal(
                  key: Key('manual-request-approve-${item.id}'),
                  onPressed: deciding ? null : onApprove,
                  child: const Text('Approve'),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                OutlinedButton(
                  key: Key('manual-request-reject-${item.id}'),
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
