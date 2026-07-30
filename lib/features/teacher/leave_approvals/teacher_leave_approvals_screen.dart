import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/approvals/approval_models.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'teacher_leave_approvals_provider.dart';
import '../../../core/errors/error_text.dart';

/// Class teacher approves/rejects their own class's student-leave requests.
class TeacherLeaveApprovalsScreen extends ConsumerWidget {
  const TeacherLeaveApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(classTeacherPendingLeavesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Student leave requests')),
      // DS V2 P4 — premium persona canvas behind the approval list.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: pending.isEmpty
            ? const AksharaEmptyState(
                icon: Icons.event_available_outlined,
                message: 'No pending leave requests for your class.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                itemCount: pending.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AksharaSpacing.s3),
                itemBuilder: (context, i) => _LeaveCard(request: pending[i]),
              ),
      ),
    );
  }
}

class _LeaveCard extends ConsumerWidget {
  const _LeaveCard({required this.request});

  final ApprovalRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final colors = context.colors;
    final p = request.payload;

    Future<void> act(Future<void> Function() run, String done) async {
      try {
        await run();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(done)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(e))));
        }
      }
    }

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p['childName'] ?? 'Student'} · ${p['classLabel'] ?? ''}',
                style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              '${p['leaveType'] ?? 'Leave'} · ${p['fromDate'] ?? ''} to ${p['toDate'] ?? ''}',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
            if ((p['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s2),
              Text('${p['reason']}', style: text.bodyMedium),
            ],
            const SizedBox(height: AksharaSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: QaTestKeys.classTeacherLeaveReject(request.id),
                    onPressed: () => act(
                      () => rejectStudentLeaveAsClassTeacher(
                          ref, request, 'Not approved'),
                      'Leave rejected',
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                Expanded(
                  child: FilledButton(
                    key: QaTestKeys.classTeacherLeaveApprove(request.id),
                    onPressed: () => act(
                      () => approveStudentLeaveAsClassTeacher(ref, request),
                      'Leave approved',
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
