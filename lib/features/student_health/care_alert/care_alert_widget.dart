import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../student_health_models.dart';
import 'care_alert_providers.dart';

/// PRC-A Batch 2 — the TEACHER care-alert surface (owner decision #1, LOCKED
/// 2026-07-15). Minimal, reusable, self-contained: pass a [studentId] and it
/// renders that student's active care alerts (label + action note + severity)
/// with NO clinical detail — the underlying [CareAlert] model has no field to
/// carry one. Not wired into any roster/profile screen yet; that is the
/// orchestrator's job when a class/student context is ready to host it.
///
/// Gating is two-layered, matching the server:
///   1. In-widget: no `viewStudentCareAlert` → renders nothing and NEVER
///      watches the provider, so it never issues the network call.
///   2. Server: `readCareAlertOp` further narrows to students the caller
///      actually teaches (a `viewStudentCareAlert` holder without
///      `viewStudentHealthRecord` gets an empty/denied result for a student
///      they don't teach) — this widget just renders whatever the server
///      honestly returns.
///
/// This widget reads ONLY `careAlertProvider` / `careAlertDataSourceProvider`
/// (care_alert_providers.dart, backed by the single-endpoint
/// [CareAlertDataSource]) — it has no reference to the clinical
/// `studentHealthDataSourceProvider` and therefore cannot reach
/// `/student-health/students/:id/record` or `/incidents`, even by mistake.
class StudentCareAlertCard extends ConsumerWidget {
  const StudentCareAlertCard({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = ref.watch(rbacServiceProvider).hasPermission(Permission.viewStudentCareAlert);
    if (!canView) {
      // No permission → render nothing. Do NOT watch careAlertProvider below
      // this line; the provider must never be created for an unauthorized
      // caller (autoDispose provider is fine, but the safest guarantee is to
      // never trigger the fetch in the first place).
      return const SizedBox.shrink();
    }
    return _CareAlertBody(studentId: studentId);
  }
}

class _CareAlertBody extends ConsumerWidget {
  const _CareAlertBody({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = resolveErpAsync(
      ref.watch(careAlertProvider(studentId)),
      errorMessage: 'Unable to load care alerts.',
    );

    return ErpAsyncBody<List<CareAlert>>(
      key: const Key('student-care-alert-body'),
      state: viewState,
      loadingLabel: 'Loading care alerts',
      emptyMessage: 'No active care alerts for this student.',
      emptyIcon: Icons.health_and_safety_outlined,
      onRetry: () => retryErpFuture(ref, careAlertProvider(studentId)),
      builder: (alerts) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final alert in alerts) ...[
            _CareAlertTile(alert: alert),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _CareAlertTile extends StatelessWidget {
  const _CareAlertTile({required this.alert});
  final CareAlert alert;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Container(
      key: Key('care-alert-tile-${alert.id}'),
      padding: const EdgeInsets.all(AksharaSpacing.s3),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.label, style: text.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                if (alert.actionNote.isNotEmpty)
                  Text(alert.actionNote, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          AksharaStatusChip(
            label: alert.severity,
            tone: switch (alert.severity) {
              'critical' => KpiAccent.error,
              'important' => KpiAccent.warning,
              _ => KpiAccent.neutral,
            },
          ),
        ],
      ),
    );
  }
}
