import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/attendance/attendance_correction_models.dart';
import '../../../core/repositories/mock/mock_attendance_sync_store.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../theme/spacing.dart';

final attendanceCorrectionsAdminProvider =
    FutureProvider<List<AttendanceCorrectionRequest>>((ref) async {
  return ref.read(attendanceCorrectionRepositoryProvider).listCorrections(
        query: ref.watch(repositoryQueryProvider),
      );
});

/// ERP admin view for attendance correction requests (P0-ATT-001).
class AttendanceCorrectionsAdminScreen extends ConsumerWidget {
  const AttendanceCorrectionsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(attendanceCorrectionsAdminProvider);
    final sync = MockAttendanceSyncStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance corrections'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(RouteNames.managementApprovals),
            icon: const Icon(Icons.approval_outlined),
            label: const Text('Approval center'),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Unable to load attendance corrections.'),
        ),
        data: (requests) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_clock_outlined),
              title: Text(
                sync.hasTeacherSubmission
                    ? 'Teacher attendance submitted'
                    : 'No teacher submission yet',
              ),
              subtitle: sync.hasTeacherSubmission
                  ? Text(
                      'Present ${sync.presentCount} · Absent ${sync.absentCount} · Late ${sync.lateCount}',
                    )
                  : const Text('Marks unlock after first class submission.'),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Text(
            'Correction requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AksharaSpacing.s2),
          if (requests.isEmpty)
            const AksharaEmptyState(
              message:
                  'No attendance correction requests. Teachers and parents submit corrections for principal approval.',
              icon: Icons.edit_calendar_outlined,
            )
          else
            ...requests.map((request) => _CorrectionTile(request: request)),
        ],
      ),
      ),
    );
  }
}

class _CorrectionTile extends StatelessWidget {
  const _CorrectionTile({required this.request});

  final AttendanceCorrectionRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${request.studentName} · ${request.classLabel}-${request.section}'),
        subtitle: Text(
          '${request.dateLabel}: ${request.fromMark} → ${request.toMark}\n'
          '${request.reason}\n'
          'By ${request.requesterName} (${request.requesterRole})',
        ),
        isThreeLine: true,
        trailing: Chip(label: Text(_statusLabel(request.status))),
      ),
    );
  }

  String _statusLabel(AttendanceCorrectionStatus status) => switch (status) {
        AttendanceCorrectionStatus.pending => 'Pending',
        AttendanceCorrectionStatus.approved => 'Approved',
        AttendanceCorrectionStatus.rejected => 'Rejected',
        AttendanceCorrectionStatus.cancelled => 'Cancelled',
      };
}
