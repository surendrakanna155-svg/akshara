import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../shared/widgets/akshara_key_value_card.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../record/student_health_record_screen.dart';
import '../student_health_datasource.dart';
import '../student_health_models.dart';
import '../student_health_providers.dart';

/// PRC-A Batch 2 — the Infirmary console for health staff.
///
/// Owner decision #1 (LOCKED 2026-07-15): every action here checks its OWN
/// permission — `manageStudentHealth` to record/author, `viewStudentHealthRecord`
/// to see the existing list (so a manage-only caller can still record NEW
/// entries but never sees history they aren't cleared for), and the narrower
/// `administerStudentMedication` to actually give a dose. Nothing here is
/// reachable without holding at least one of those.
class StudentHealthInfirmaryScreen extends ConsumerStatefulWidget {
  const StudentHealthInfirmaryScreen({super.key, this.initialStudentId});

  /// Optional pre-selected student (e.g. deep-linked from a roster later —
  /// the orchestrator's job to wire). When absent, staff enter an ID.
  final String? initialStudentId;

  @override
  ConsumerState<StudentHealthInfirmaryScreen> createState() =>
      _StudentHealthInfirmaryScreenState();
}

class _StudentHealthInfirmaryScreenState extends ConsumerState<StudentHealthInfirmaryScreen> {
  late final _studentIdField = TextEditingController(text: widget.initialStudentId ?? '');
  String? _activeStudentId;

  @override
  void initState() {
    super.initState();
    _activeStudentId = widget.initialStudentId;
  }

  @override
  void dispose() {
    _studentIdField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rbac = ref.watch(rbacServiceProvider);
    final canManage = rbac.hasPermission(Permission.manageStudentHealth);
    final canViewRecord = rbac.hasPermission(Permission.viewStudentHealthRecord);
    final studentId = _activeStudentId;

    return Scaffold(
      appBar: AppBar(title: const Text('Infirmary')),
      body: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('infirmary-student-id-field'),
                    controller: _studentIdField,
                    decoration: const InputDecoration(labelText: 'Student ID'),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                FilledButton(
                  key: const Key('infirmary-load-student-button'),
                  onPressed: () => setState(() {
                    _activeStudentId = _studentIdField.text.trim().isEmpty
                        ? null
                        : _studentIdField.text.trim();
                  }),
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            if (studentId == null)
              const Expanded(
                child: Center(child: Text('Enter a student ID to begin.')),
              )
            else
              Expanded(
                child: _StudentWorkspace(
                  key: ValueKey('infirmary-workspace-$studentId'),
                  studentId: studentId,
                  canManage: canManage,
                  canViewRecord: canViewRecord,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentWorkspace extends ConsumerWidget {
  const _StudentWorkspace({
    super.key,
    required this.studentId,
    required this.canManage,
    required this.canViewRecord,
  });

  final String studentId;
  final bool canManage;
  final bool canViewRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdminister =
        ref.watch(rbacServiceProvider).hasPermission(Permission.administerStudentMedication);

    return ListView(
      children: [
        Wrap(
          spacing: AksharaSpacing.s2,
          runSpacing: AksharaSpacing.s2,
          children: [
            AksharaManageAction(
              permission: Permission.manageStudentHealth,
              auditRoute: RouteNames.studentHealth,
              child: OutlinedButton.icon(
                key: const Key('infirmary-record-incident-button'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _RecordIncidentDialog(studentId: studentId),
                ),
                icon: const Icon(Icons.local_hospital_outlined, size: 18),
                label: const Text('Record incident'),
              ),
            ),
            AksharaManageAction(
              permission: Permission.manageStudentHealth,
              auditRoute: RouteNames.studentHealth,
              child: OutlinedButton.icon(
                key: const Key('infirmary-new-care-alert-button'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _CareAlertDialog(studentId: studentId),
                ),
                icon: const Icon(Icons.notification_important_outlined, size: 18),
                label: const Text('New care alert'),
              ),
            ),
            AksharaManageAction(
              permission: Permission.manageStudentHealth,
              auditRoute: RouteNames.studentHealth,
              child: OutlinedButton.icon(
                key: const Key('infirmary-new-authorization-button'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _AuthorizationDialog(studentId: studentId),
                ),
                icon: const Icon(Icons.medication_outlined, size: 18),
                label: const Text('New medication authorization'),
              ),
            ),
            if (canAdminister)
              OutlinedButton.icon(
                key: const Key('infirmary-administer-by-id-button'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _AdministerDialog(studentId: studentId),
                ),
                icon: const Icon(Icons.vaccines_outlined, size: 18),
                label: const Text('Administer by authorization ID'),
              ),
            if (canViewRecord)
              OutlinedButton.icon(
                key: const Key('infirmary-view-record-button'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentHealthRecordScreen(studentId: studentId),
                  ),
                ),
                icon: const Icon(Icons.folder_shared_outlined, size: 18),
                label: const Text('View full clinical record'),
              ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s5),
        if (!canViewRecord)
          Text(
            'You can record new entries. Existing incidents, care alerts and '
            'medication authorizations require clinical-record access '
            '(viewStudentHealthRecord) to display.',
            style: context.aksharaText.bodySmall
                .copyWith(color: context.colors.onSurfaceVariant),
          )
        else
          _RecordSections(studentId: studentId, canAdminister: canAdminister),
      ],
    );
  }
}

class _RecordSections extends ConsumerWidget {
  const _RecordSections({required this.studentId, required this.canAdminister});
  final String studentId;
  final bool canAdminister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = resolveErpAsync(
      ref.watch(studentHealthRecordProvider(studentId)),
      errorMessage: 'Unable to load this student\'s clinical record.',
      isDataEmpty: (r) =>
          r.incidents.isEmpty && r.activeAuthorizations.isEmpty && r.careAlerts.isEmpty,
    );

    return ErpAsyncBody<StudentHealthRecord>(
      state: viewState,
      loadingLabel: 'Loading clinical record',
      emptyMessage: 'No clinical entries recorded yet for this student.',
      onRetry: () => retryErpFuture(ref, studentHealthRecordProvider(studentId)),
      builder: (record) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (record.careAlerts.isNotEmpty) ...[
            const AksharaSectionHeader(title: 'Active care alerts', fixedHeight: false),
            const SizedBox(height: AksharaSpacing.s2),
            for (final alert in record.careAlerts) _CareAlertManageRow(alert: alert),
            const SizedBox(height: AksharaSpacing.s4),
          ],
          if (record.activeAuthorizations.isNotEmpty) ...[
            const AksharaSectionHeader(title: 'Medication authorizations', fixedHeight: false),
            const SizedBox(height: AksharaSpacing.s2),
            for (final auth in record.activeAuthorizations)
              _AuthorizationManageRow(auth: auth, canAdminister: canAdminister),
            const SizedBox(height: AksharaSpacing.s4),
          ],
          if (record.incidents.isNotEmpty) ...[
            const AksharaSectionHeader(title: 'Incident history', fixedHeight: false),
            const SizedBox(height: AksharaSpacing.s2),
            for (final incident in record.incidents) _IncidentRow(incident: incident),
          ],
        ],
      ),
    );
  }
}

class _CareAlertManageRow extends ConsumerWidget {
  const _CareAlertManageRow({required this.alert});
  final CareAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaKeyValueCard(
      title: alert.label,
      entries: [
        ('Action', alert.actionNote),
        ('Severity', alert.severity),
      ],
      trailing: AksharaManageAction(
        permission: Permission.manageStudentHealth,
        auditRoute: RouteNames.studentHealth,
        child: TextButton(
          key: Key('care-alert-deactivate-${alert.id}'),
          onPressed: () async {
            try {
              await ref
                  .read(studentHealthDataSourceProvider)
                  .updateCareAlert(alertId: alert.id, isActive: false);
              ref.invalidate(studentHealthRecordProvider(alert.studentId));
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not deactivate the alert.')),
                );
              }
            }
          },
          child: const Text('Deactivate'),
        ),
      ),
    );
  }
}

class _AuthorizationManageRow extends ConsumerWidget {
  const _AuthorizationManageRow({required this.auth, required this.canAdminister});
  final MedicationAuthorization auth;
  final bool canAdminister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaKeyValueCard(
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
        ('Consent', '${auth.authorizationSource} (${auth.authorizationRef})'),
      ],
      trailing: Wrap(
        spacing: AksharaSpacing.s2,
        children: [
          if (canAdminister && auth.isActive)
            TextButton(
              key: Key('authorization-administer-${auth.id}'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _AdministerDialog(
                  studentId: auth.studentId,
                  authorizationId: auth.id,
                  medicationLabel: '${auth.medicationName} (${auth.dosage})',
                ),
              ),
              child: const Text('Administer'),
            ),
          if (auth.isActive)
            AksharaManageAction(
              permission: Permission.manageStudentHealth,
              auditRoute: RouteNames.studentHealth,
              child: TextButton(
                key: Key('authorization-revoke-${auth.id}'),
                onPressed: () async {
                  try {
                    await ref.read(studentHealthDataSourceProvider).revokeAuthorization(auth.id);
                    ref.invalidate(studentHealthRecordProvider(auth.studentId));
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not revoke the authorization.')),
                      );
                    }
                  }
                },
                child: const Text('Revoke'),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident});
  final HealthIncident incident;

  @override
  Widget build(BuildContext context) {
    return AksharaKeyValueCard(
      title: incident.incidentType,
      entries: [
        ('Occurred', incident.occurredAt),
        ('Summary', incident.complaintSummary),
        ('Outcome', incident.outcome),
      ],
    );
  }
}

class _RecordIncidentDialog extends ConsumerStatefulWidget {
  const _RecordIncidentDialog({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_RecordIncidentDialog> createState() => _RecordIncidentDialogState();
}

class _RecordIncidentDialogState extends ConsumerState<_RecordIncidentDialog> {
  final _complaintSummary = TextEditingController();
  final _observations = TextEditingController();
  final _treatmentGiven = TextEditingController();
  String _incidentType = kIncidentTypes.first;
  String _outcome = kIncidentOutcomes.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _complaintSummary.dispose();
    _observations.dispose();
    _treatmentGiven.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(studentHealthDataSourceProvider).recordIncident(
            studentId: widget.studentId,
            incidentType: _incidentType,
            complaintSummary: _complaintSummary.text.trim(),
            observations: _observations.text.trim(),
            treatmentGiven: _treatmentGiven.text.trim(),
            outcome: _outcome,
          );
      if (!mounted) return;
      ref.invalidate(studentHealthRecordProvider(widget.studentId));
      Navigator.of(context).pop();
      // Generic, clinical-detail-free confirmation — a count only.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incident recorded. ${result.notifiedGuardians} guardian(s) notified.',
          ),
        ),
      );
    } on StudentHealthActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not record the incident. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('record-incident-dialog'),
      title: const Text('Record incident'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('incident-type-field'),
                initialValue: _incidentType,
                decoration: const InputDecoration(labelText: 'Incident type'),
                items: [for (final t in kIncidentTypes) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: _busy ? null : (v) => setState(() => _incidentType = v ?? _incidentType),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('incident-summary-field'),
                controller: _complaintSummary,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Complaint summary'),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('incident-observations-field'),
                controller: _observations,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observations'),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('incident-treatment-field'),
                controller: _treatmentGiven,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Treatment given'),
              ),
              const AksharaDialogFieldGap(),
              DropdownButtonFormField<String>(
                key: const Key('incident-outcome-field'),
                initialValue: _outcome,
                decoration: InputDecoration(labelText: 'Outcome', errorText: _error),
                items: [for (final o in kIncidentOutcomes) DropdownMenuItem(value: o, child: Text(o))],
                onChanged: _busy ? null : (v) => setState(() => _outcome = v ?? _outcome),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('record-incident-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Record'),
        ),
      ],
    );
  }
}

class _CareAlertDialog extends ConsumerStatefulWidget {
  const _CareAlertDialog({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_CareAlertDialog> createState() => _CareAlertDialogState();
}

class _CareAlertDialogState extends ConsumerState<_CareAlertDialog> {
  final _label = TextEditingController();
  final _actionNote = TextEditingController();
  String _severity = 'important';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _actionNote.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final label = _label.text.trim();
    if (label.length < 3) {
      setState(() => _error = 'Give a label (at least 3 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(studentHealthDataSourceProvider).createCareAlert(
            studentId: widget.studentId,
            label: label,
            actionNote: _actionNote.text.trim(),
            severity: _severity,
          );
      if (!mounted) return;
      ref.invalidate(studentHealthRecordProvider(widget.studentId));
      Navigator.of(context).pop();
    } on StudentHealthActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save the care alert. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('care-alert-create-dialog'),
      title: const Text('New care alert'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('care-alert-label-field'),
            controller: _label,
            enabled: !_busy,
            decoration: InputDecoration(labelText: 'Label (shown to teachers)', errorText: _error),
          ),
          const AksharaDialogFieldGap(),
          TextField(
            key: const Key('care-alert-action-field'),
            controller: _actionNote,
            enabled: !_busy,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'What a teacher should do'),
          ),
          const AksharaDialogFieldGap(),
          DropdownButtonFormField<String>(
            key: const Key('care-alert-severity-field'),
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: [for (final s in kCareAlertSeverities) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: _busy ? null : (v) => setState(() => _severity = v ?? _severity),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('care-alert-create-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AuthorizationDialog extends ConsumerStatefulWidget {
  const _AuthorizationDialog({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_AuthorizationDialog> createState() => _AuthorizationDialogState();
}

class _AuthorizationDialogState extends ConsumerState<_AuthorizationDialog> {
  final _medicationName = TextEditingController();
  final _dosage = TextEditingController();
  final _validFrom = TextEditingController();
  final _authorizationRef = TextEditingController();
  String _source = kAuthorizationSources.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _medicationName.dispose();
    _dosage.dispose();
    _validFrom.dispose();
    _authorizationRef.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(studentHealthDataSourceProvider).createAuthorization(
            studentId: widget.studentId,
            medicationName: _medicationName.text.trim(),
            dosage: _dosage.text.trim(),
            validFrom: _validFrom.text.trim(),
            authorizationSource: _source,
            authorizationRef: _authorizationRef.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(studentHealthRecordProvider(widget.studentId));
      Navigator.of(context).pop();
    } on StudentHealthActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save the authorization. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('authorization-create-dialog'),
      title: const Text('New medication authorization'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('authorization-medication-field'),
                controller: _medicationName,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Medication name'),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('authorization-dosage-field'),
                controller: _dosage,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('authorization-valid-from-field'),
                controller: _validFrom,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Valid from (YYYY-MM-DD)'),
              ),
              const AksharaDialogFieldGap(),
              DropdownButtonFormField<String>(
                key: const Key('authorization-source-field'),
                initialValue: _source,
                decoration: const InputDecoration(labelText: 'Consent source'),
                items: [
                  for (final s in kAuthorizationSources) DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _source = v ?? _source),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('authorization-ref-field'),
                controller: _authorizationRef,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Consent reference (form ID, prescription no., etc.)',
                  errorText: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('authorization-create-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AdministerDialog extends ConsumerStatefulWidget {
  const _AdministerDialog({
    required this.studentId,
    this.authorizationId,
    this.medicationLabel,
  });

  final String studentId;
  final String? authorizationId;
  final String? medicationLabel;

  @override
  ConsumerState<_AdministerDialog> createState() => _AdministerDialogState();
}

class _AdministerDialogState extends ConsumerState<_AdministerDialog> {
  late final _authorizationId = TextEditingController(text: widget.authorizationId ?? '');
  final _dosageGiven = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _authorizationId.dispose();
    _dosageGiven.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authId = _authorizationId.text.trim();
    final dosage = _dosageGiven.text.trim();
    if (authId.isEmpty || dosage.isEmpty) {
      setState(() => _error = 'Authorization ID and dosage given are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(studentHealthDataSourceProvider).administerMedication(
            authorizationId: authId,
            expectedStudentId: widget.studentId,
            dosageGiven: dosage,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(studentHealthRecordProvider(widget.studentId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication administered and logged.')),
      );
    } on StudentHealthActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not log the administration. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('administer-medication-dialog'),
      title: const Text('Administer medication'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.medicationLabel != null) ...[
            Text(widget.medicationLabel!, style: context.aksharaText.bodyMedium),
            const AksharaDialogFieldGap(),
          ],
          TextField(
            key: const Key('administer-authorization-id-field'),
            controller: _authorizationId,
            enabled: !_busy && widget.authorizationId == null,
            decoration: const InputDecoration(labelText: 'Authorization ID'),
          ),
          const AksharaDialogFieldGap(),
          TextField(
            key: const Key('administer-dosage-field'),
            controller: _dosageGiven,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Dosage given'),
          ),
          const AksharaDialogFieldGap(),
          TextField(
            key: const Key('administer-note-field'),
            controller: _note,
            enabled: !_busy,
            decoration: InputDecoration(labelText: 'Note (optional)', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('administer-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Administer'),
        ),
      ],
    );
  }
}
