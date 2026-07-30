import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/attendance/attendance_correction_models.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/premium/akshara_premium_background.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

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

    return Scaffold(
      // DS V2 P4 — persona (admin/indigo) premium canvas behind the corrections
      // approval workspace.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Attendance corrections'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(RouteNames.managementOfficeAttendance),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Office attendance'),
          ),
          TextButton.icon(
            onPressed: () => context.go(RouteNames.managementApprovals),
            icon: const Icon(Icons.approval_outlined),
            label: const Text('Approval center'),
          ),
        ],
      ),
      body: AksharaPremiumBackground(
        showMotif: false,
        child: ErpAsyncBody(
          state: resolveErpAsync(requestsAsync, isDataEmpty: (_) => false),
          loadingLabel: 'Loading',
          emptyMessage: 'No attendance correction requests.',
          onRetry: () => ref.invalidate(attendanceCorrectionsAdminProvider),
          builder: (requests) => ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              // E2E-005 — the "teacher submission" card is gone. It was driven
              // by `MockAttendanceSyncStore`, an in-memory QA shim whose only
              // writer is `MockTeacherRepository`. In a release build the
              // teacher app resolves the API repository, so the store was never
              // written and the card told the principal, as fact, that no
              // teacher had submitted — on a day when every class had.
              // It returns only when it is sourced from `GET /attendance/pending`.
              Text(
                'Correction requests',
                style: context.aksharaText.titleMedium,
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
        title: Text(
            '${request.studentName} · ${request.classLabel}-${request.section}'),
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
