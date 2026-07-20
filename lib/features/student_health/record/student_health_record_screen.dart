import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_key_value_card.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../student_health_models.dart';
import '../student_health_providers.dart';

/// PRC-A Batch 2 — the FULL clinical record for one student.
///
/// Owner decision #1 (LOCKED 2026-07-15): gated on `viewStudentHealthRecord`
/// (health staff + explicitly authorised leadership only — the server grants
/// it to nobody else). The permission is checked BEFORE any provider is
/// watched, so an unauthorized caller never triggers the record fetch (and
/// never generates a server-side access-log row for a read that never
/// happened). Includes the access log — "who viewed this child's data" — the
/// transparency the owner decision is built on.
class StudentHealthRecordScreen extends ConsumerWidget {
  const StudentHealthRecordScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = ref.watch(rbacServiceProvider).hasPermission(Permission.viewStudentHealthRecord);
    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clinical record')),
        body: const Center(
          key: Key('student-health-record-restricted'),
          child: Padding(
            padding: EdgeInsets.all(AksharaSpacing.s6),
            child: Text(
              'Access restricted. This clinical record is visible only to '
              'health staff and explicitly authorised leadership.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final viewState = resolveErpAsync(
      ref.watch(studentHealthRecordProvider(studentId)),
      errorMessage: 'Unable to load this student\'s clinical record.',
      isDataEmpty: (r) =>
          r.incidents.isEmpty && r.activeAuthorizations.isEmpty && r.careAlerts.isEmpty,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Clinical record')),
      body: ErpAsyncBody<StudentHealthRecord>(
        state: viewState,
        loadingLabel: 'Loading clinical record',
        emptyMessage: 'No clinical entries recorded yet for this student.',
        onRetry: () => retryErpFuture(ref, studentHealthRecordProvider(studentId)),
        builder: (record) => _RecordBody(studentId: studentId, record: record),
      ),
    );
  }
}

class _RecordBody extends ConsumerWidget {
  const _RecordBody({required this.studentId, required this.record});
  final String studentId;
  final StudentHealthRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (record.careAlerts.isNotEmpty) ...[
          const AksharaSectionHeader(title: 'Active care alerts', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          for (final alert in record.careAlerts)
            AksharaKeyValueCard(
              title: alert.label,
              entries: [
                ('Action', alert.actionNote),
                ('Severity', alert.severity),
              ],
            ),
          const SizedBox(height: AksharaSpacing.s4),
        ],
        if (record.activeAuthorizations.isNotEmpty) ...[
          const AksharaSectionHeader(title: 'Medication authorizations', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          for (final auth in record.activeAuthorizations)
            AksharaKeyValueCard(
              titleWidget: Row(
                children: [
                  Expanded(child: Text(auth.medicationName, style: context.aksharaText.titleSmall)),
                  AksharaStatusChip(
                    label: auth.status,
                    tone: auth.isActive ? KpiAccent.success : KpiAccent.neutral,
                  ),
                ],
              ),
              entries: [
                ('Dosage', '${auth.dosage} · ${auth.route}'),
                ('Valid', '${auth.validFrom} – ${auth.validUntil ?? 'ongoing'}'),
              ],
            ),
          const SizedBox(height: AksharaSpacing.s4),
        ],
        if (record.recentAdministrations.isNotEmpty) ...[
          const AksharaSectionHeader(title: 'Recent administrations', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          for (final admin in record.recentAdministrations)
            AksharaKeyValueCard(
              title: admin.administeredAt,
              entries: [
                ('Dosage given', admin.dosageGiven),
                if (admin.note.isNotEmpty) ('Note', admin.note),
              ],
            ),
          const SizedBox(height: AksharaSpacing.s4),
        ],
        if (record.incidents.isNotEmpty) ...[
          const AksharaSectionHeader(title: 'Incident history', fixedHeight: false),
          const SizedBox(height: AksharaSpacing.s2),
          for (final incident in record.incidents)
            AksharaKeyValueCard(
              title: incident.incidentType,
              entries: [
                ('Occurred', incident.occurredAt),
                ('Summary', incident.complaintSummary),
                ('Observations', incident.observations),
                ('Treatment', incident.treatmentGiven),
                ('Outcome', incident.outcome),
              ],
            ),
          const SizedBox(height: AksharaSpacing.s4),
        ],
        const AksharaSectionHeader(title: 'Who has viewed this record', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        _AccessLogSection(studentId: studentId),
      ],
    );
  }
}

class _AccessLogSection extends ConsumerWidget {
  const _AccessLogSection({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = resolveErpAsync(
      ref.watch(studentHealthAccessLogProvider(studentId)),
      errorMessage: 'Unable to load the access log.',
    );

    return ErpAsyncBody<List<HealthAccessLogEntry>>(
      key: const Key('student-health-access-log'),
      state: viewState,
      loadingLabel: 'Loading access log',
      emptyMessage: 'No recorded accesses yet.',
      emptyIcon: Icons.visibility_outlined,
      onRetry: () => retryErpFuture(ref, studentHealthAccessLogProvider(studentId)),
      builder: (entries) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries)
            AksharaKeyValueCard(
              title: '${entry.actorRole} · ${entry.accessKind}',
              entries: [
                ('When', entry.occurredAt),
                ('Route', entry.route),
                if (entry.purpose.isNotEmpty) ('Purpose', entry.purpose),
              ],
            ),
        ],
      ),
    );
  }
}
