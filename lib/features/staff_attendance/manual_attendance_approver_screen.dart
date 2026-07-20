import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import 'manual_attendance_request_models.dart';
import 'manual_attendance_request_providers.dart';

/// PRA-P0-15 — the approver side of the audited manual-attendance fallback.
/// Lists pending manual requests for the school and lets a holder of
/// `approveStaffAttendance` approve/reject each one. Approving mints a real
/// check-in server-side (POST /staff-attendance/manual-request/decide).
///
/// The nav entry is gated on [canApproveManualAttendanceProvider]; the server
/// re-enforces `approveStaffAttendance` on every decide.
class ManualAttendanceApproverScreen extends ConsumerStatefulWidget {
  const ManualAttendanceApproverScreen({super.key});

  @override
  ConsumerState<ManualAttendanceApproverScreen> createState() =>
      _ManualAttendanceApproverScreenState();
}

class _ManualAttendanceApproverScreenState
    extends ConsumerState<ManualAttendanceApproverScreen> {
  final Set<String> _deciding = <String>{};

  Future<void> _decide(ManualAttendanceRequest request, bool approve) async {
    if (_deciding.contains(request.id)) return;
    setState(() => _deciding.add(request.id));
    try {
      final decision =
          await ref.read(manualAttendanceRequestDataSourceProvider).decide(
                requestId: request.id,
                approve: approve,
              );
      if (!mounted) return;
      final verb = decision.isApproved ? 'approved' : 'rejected';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('manual-approver-decided-snackbar'),
          content: Text('Request $verb.'),
        ),
      );
      ref.invalidate(pendingManualAttendanceRequestsProvider);
    } on ManualAttendanceRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record the decision.')),
      );
    } finally {
      if (mounted) setState(() => _deciding.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(pendingManualAttendanceRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manual attendance requests')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(pendingManualAttendanceRequestsProvider),
        child: requestsAsync.when(
          loading: () => const AksharaLoadingState(
            semanticLabel: 'Loading manual attendance requests',
          ),
          error: (_, __) => AksharaErrorState(
            message: 'Unable to load manual attendance requests.',
            onRetry: () =>
                ref.invalidate(pendingManualAttendanceRequestsProvider),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  AksharaEmptyState(
                    message: 'No pending manual attendance requests.',
                    icon: Icons.fact_check_outlined,
                  ),
                ],
              );
            }
            return ListView.separated(
              key: const Key('manual-approver-list'),
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RequestCard(
                  request: request,
                  busy: _deciding.contains(request.id),
                  onApprove: () => _decide(request, true),
                  onReject: () => _decide(request, false),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final ManualAttendanceRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = request.staffName.isEmpty ? 'Staff member' : request.staffName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  request.eventType.apiValue == 'check_out'
                      ? Icons.logout
                      : Icons.login,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name · ${request.eventType.label}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.reason.isEmpty ? 'No reason provided.' : request.reason,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Recording decision…'),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: Key('manual-approver-reject-${request.id}'),
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: Key('manual-approver-approve-${request.id}'),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
