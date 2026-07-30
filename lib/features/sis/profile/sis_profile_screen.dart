import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../clearance/widgets/clearance_report_dialog.dart';
import '../../clearance/widgets/clearance_waiver_queue_dialog.dart';
import '../../../router/route_names.dart';
import '../../../router/student360_navigation.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../sis_mutations_provider.dart';
import '../sis_navigation.dart';
import '../sis_requests.dart';
import '../sis_workflow_actions.dart';
import '../widgets/sis_kpi_row.dart';
import '../widgets/sis_module_scaffold.dart';
import 'sis_profile_provider.dart';

/// SIS-03 — Student Profile.
class SisStudentProfileScreen extends ConsumerWidget {
  const SisStudentProfileScreen({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(sisStudentProfileViewStateProvider(studentId));
    final profile =
        viewState.data ?? ref.watch(sisStudentProfileProvider(studentId));

    return SisModuleScaffold(
      screen: SisScreen.registry,
      breadcrumbs: profile == null
          ? sisBreadcrumbs(SisScreen.registry)
          : sisStudentProfileBreadcrumbs(
              studentName: profile.student.studentName,
            ),
      showFilterBar: false,
      body: SisAsyncBody<SisStudentProfile>(
        state: viewState.data == null && profile != null
            ? SisViewState(data: profile)
            : viewState,
        loadingLabel: 'Loading student profile',
        emptyMessage: 'Student profile not found.',
        emptyIcon: Icons.person_outline,
        onRetry: () => retrySisFuture(
          ref,
          sisStudentProfileFutureProvider(studentId),
        ),
        builder: (loadedProfile) => _buildProfileContent(
          context,
          ref: ref,
          profile: loadedProfile,
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context, {
    required WidgetRef ref,
    required SisStudentProfile profile,
  }) {
    final student = profile.student;
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(title: student.studentName),
        Text(
          '${student.admissionNumber} · Class ${student.classLabel}-${student.section}',
          style: context.aksharaText.bodyMedium,
        ),
        // Identity Platform: the permanent public student ID (F1/F2). Shows "—"
        // for a code-less school (backend sends it null).
        Text(
          'Public ID: ${_psidLabel(student.publicStudentId)}',
          key: QaTestKeys.sisProfilePublicId,
          style: context.aksharaText.bodySmall,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        Wrap(
          spacing: AksharaSpacing.s2,
          runSpacing: AksharaSpacing.s2,
          children: [
            AksharaManageAction(
              permission: Permission.manageSis,
              child: OutlinedButton.icon(
                key: QaTestKeys.sisEditProfileButton,
                onPressed: () => showSisProfileEditSheet(
                  context,
                  ref,
                  profile: profile,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
              ),
            ),
            // SIS-1: issue a bonafide/study/conduct certificate → render PDF.
            AksharaManageAction(
              permission: Permission.manageSis,
              child: OutlinedButton.icon(
                key: QaTestKeys.sisIssueCertificateButton,
                onPressed: () => showSisIssueCertificateDialog(
                  context,
                  ref,
                  profile: profile,
                ),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Issue certificate'),
              ),
            ),
            // SIS-D1: transfer certificate (no-dues gated) → status transferred.
            AksharaManageAction(
              permission: Permission.manageSis,
              child: OutlinedButton.icon(
                key: QaTestKeys.sisTransferCertificateButton,
                onPressed: () => showSisTransferCertificateDialog(
                  context,
                  ref,
                  profile: profile,
                ),
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Transfer certificate'),
              ),
            ),
            // SCE-1: the cross-module no-dues clearance report (+ dues-waiver
            // request when blocked). Same manageSis gate as the TC it precedes.
            AksharaManageAction(
              permission: Permission.manageSis,
              child: OutlinedButton.icon(
                key: const Key('sis-clearance-report-button'),
                onPressed: () => ClearanceReportDialog.show(
                  context,
                  studentId: student.id,
                  studentName: student.studentName,
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Clearance'),
              ),
            ),
            // SCE-1: the dues-waiver approver queue (checker side of the maker-
            // checker). Visible only to holders of approveClearanceWaiver.
            if (ref.watch(rbacServiceProvider).hasPermission(Permission.approveClearanceWaiver))
              OutlinedButton.icon(
                key: const Key('sis-clearance-waivers-button'),
                onPressed: () => ClearanceWaiverQueueDialog.show(context),
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('Waivers'),
              ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        SisKpiRow(
          desktopColumns: 4,
          cardHeight: 100,
          kpis: [
            SisKpi(
              id: 'status',
              value: _statusLabel(student.status),
              label: 'Status',
              icon: Icons.info_outline,
              accentName: 'primary',
            ),
            SisKpi(
              id: 'attendance',
              value: profile.attendance.presentPercent,
              label: 'Attendance',
              icon: Icons.event_available_outlined,
              accentName: 'success',
            ),
            SisKpi(
              id: 'fee_balance',
              value: profile.feeAccount?.balance ?? '—',
              label: 'Fee balance',
              icon: Icons.account_balance_wallet_outlined,
              accentName: profile.feeAccount != null ? 'warning' : 'neutral',
            ),
            SisKpi(
              id: 'documents',
              value: '${profile.documents.length}',
              label: 'Documents',
              icon: Icons.folder_outlined,
              accentName: 'neutral',
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        _Student360DossierCard(studentId: student.id),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _DetailSection(
              title: 'Student details', child: _StudentDetails(student)),
          _DetailSection(
              title: 'Parent details', child: _ParentDetails(profile.parent)),
          if (profile.feeAccount != null)
            _DetailSection(
              title: 'Fee account summary',
              child: _FeeSummary(account: profile.feeAccount!),
            ),
          _DetailSection(
            title: 'Documents',
            child: _DocumentsList(
              documents: profile.documents,
              onUploadDocument: () => showSisDocumentUploadDialog(
                context,
                ref,
                profile: profile,
              ),
              onDecideDocument: (document, decision) =>
                  showSisDocumentVerifyDialog(
                context,
                ref,
                profile: profile,
                document: document,
                decision: decision,
              ),
            ),
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _DetailSection(
                      title: 'Student details',
                      child: _StudentDetails(student),
                    ),
                    _DetailSection(
                      title: 'Parent details',
                      child: _ParentDetails(profile.parent),
                    ),
                    if (profile.feeAccount != null)
                      _DetailSection(
                        title: 'Fee account summary',
                        child: _FeeSummary(account: profile.feeAccount!),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                flex: 3,
                child: _DetailSection(
                  title: 'Documents',
                  child: _DocumentsList(
                    documents: profile.documents,
                    onUploadDocument: () => showSisDocumentUploadDialog(
                      context,
                      ref,
                      profile: profile,
                    ),
                    onDecideDocument: (document, decision) =>
                        showSisDocumentVerifyDialog(
                      context,
                      ref,
                      profile: profile,
                      document: document,
                      decision: decision,
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        // SIS-4 — read-only siblings / family (other students in this school
        // sharing an active guardian). viewSis-gated; hidden entirely without it.
        AksharaViewAction(
          permission: Permission.viewSis,
          child: _DetailSection(
            title: 'Siblings / Family',
            child: _SiblingsSection(studentId: student.id),
          ),
        ),
        _DetailSection(
          title: 'Certificates',
          child: _CertificateRegister(studentId: student.id),
        ),
      ],
    );
  }

  /// Public Student ID shown on the header; "—" when the school has no code.
  static String _psidLabel(String? publicStudentId) =>
      (publicStudentId == null || publicStudentId.trim().isEmpty)
          ? '—'
          : publicStudentId.trim();

  static String _statusLabel(SisStudentStatus status) => switch (status) {
        SisStudentStatus.active => 'Active',
        SisStudentStatus.prospect => 'Prospect',
        SisStudentStatus.transferred => 'Transferred',
        SisStudentStatus.exited => 'Exited',
        SisStudentStatus.alumni => 'Alumni',
      };
}

class _Student360DossierCard extends StatelessWidget {
  const _Student360DossierCard({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student 360 dossier', style: text.titleMedium),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Attendance, academics, homework, fees, behaviour, transport, '
              'and communication live in the unified Student 360 view.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            AksharaViewAction(
              permission: Permission.viewStudent360,
              child: FilledButton.icon(
                key: QaTestKeys.sisOpenStudent360Button(studentId),
                onPressed: () => openStudent360(context, studentId),
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Open Student 360'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(title: title),
          const SizedBox(height: AksharaSpacing.s3),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s5),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDetails extends StatelessWidget {
  const _StudentDetails(this.student);

  final SisStudent student;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DOB: ${student.dateOfBirth}', style: text.bodyMedium),
        Text('Gender: ${student.gender}', style: text.bodyMedium),
        Text('Academic year: ${student.academicYear}', style: text.bodyMedium),
        Text('Enrolled: ${student.enrolledAt}', style: text.bodyMedium),
      ],
    );
  }
}

class _ParentDetails extends StatelessWidget {
  const _ParentDetails(this.parent);

  final SisParentDetails parent;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(parent.guardianName, style: text.titleSmall),
        Text('${parent.relationship} · ${parent.phone}',
            style: text.bodyMedium),
        Text(parent.email, style: text.bodySmall),
        Text(parent.address, style: text.bodySmall),
      ],
    );
  }
}

class _FeeSummary extends StatelessWidget {
  const _FeeSummary({required this.account});

  final SisFeeAccountSummary account;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(account.feeStructureName, style: text.titleSmall),
        Text('Total due: ${account.totalDue}', style: text.bodyMedium),
        Text('Paid: ${account.totalPaid}', style: text.bodyMedium),
        Text('Balance: ${account.balance}', style: text.bodyMedium),
        const SizedBox(height: AksharaSpacing.s2),
        AksharaStatusChip(
          label: account.status,
          tone:
              account.status == 'Overdue' ? KpiAccent.error : KpiAccent.success,
        ),
      ],
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({
    required this.documents,
    this.onUploadDocument,
    this.onDecideDocument,
  });

  final List<SisDocumentSummary> documents;
  final VoidCallback? onUploadDocument;

  /// SIS-3 — invoked with the pending document + verify/reject decision.
  final void Function(SisDocumentSummary document, SisDocumentDecision decision)?
      onDecideDocument;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onUploadDocument != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: AksharaManageAction(
                permission: Permission.manageSis,
                child: OutlinedButton.icon(
                  key: QaTestKeys.sisUploadDocumentButton,
                  onPressed: onUploadDocument,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload Document'),
                ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
          for (final doc in documents)
            _DocumentRow(document: doc, onDecide: onDecideDocument),
        ],
      ),
    );
  }
}

/// SIS-3 — one document row: type + status chip, uploaded/verified metadata,
/// and Verify / Reject actions (manageSis-gated) while the document is pending.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, this.onDecide});

  final SisDocumentSummary document;
  final void Function(SisDocumentSummary document, SisDocumentDecision decision)?
      onDecide;

  bool get _isPending => document.status.trim().toLowerCase() == 'pending';

  (String, KpiAccent) get _statusChip =>
      switch (document.status.trim().toLowerCase()) {
        'verified' => ('Verified', KpiAccent.success),
        'rejected' => ('Rejected', KpiAccent.error),
        'pending' => ('Pending', KpiAccent.warning),
        _ => (document.status, KpiAccent.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final (statusLabel, statusTone) = _statusChip;
    final verifiedBy = document.verifiedBy;
    final documentId = document.id;
    final canDecide = _isPending && onDecide != null && documentId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(document.type, style: text.titleSmall)),
              AksharaStatusChip(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            verifiedBy == null || verifiedBy.isEmpty
                ? 'Uploaded ${document.uploadedAt}'
                : 'Uploaded ${document.uploadedAt} · '
                    '$statusLabel by $verifiedBy',
            style: text.bodySmall,
          ),
          if (canDecide) ...[
            const SizedBox(height: AksharaSpacing.s2),
            AksharaManageAction(
              permission: Permission.manageSis,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    key: QaTestKeys.sisDocumentVerifyButton(documentId),
                    onPressed: () =>
                        onDecide!(document, SisDocumentDecision.verified),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Verify'),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  OutlinedButton.icon(
                    key: QaTestKeys.sisDocumentRejectButton(documentId),
                    onPressed: () =>
                        onDecide!(document, SisDocumentDecision.rejected),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Reject'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// SIS-4 — the read-only "Siblings / Family" section: other students in the
/// same school who share an active guardian with this student, self-excluded.
/// Reads from [sisStudentSiblingsProvider]; each sibling links to their profile.
class _SiblingsSection extends ConsumerWidget {
  const _SiblingsSection({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final siblings = ref.watch(sisStudentSiblingsProvider(studentId));

    return Material(
      key: QaTestKeys.sisSiblingsSection,
      child: siblings.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s3),
          child: LinearProgressIndicator(),
        ),
        error: (_, __) => Text(
          'Could not load siblings.',
          style: text.bodySmall,
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'No siblings on record in this school.',
              style: text.bodyMedium,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final sibling in items) _SiblingRow(sibling: sibling),
            ],
          );
        },
      ),
    );
  }
}

/// SIS-4 — one sibling row: name + admission / class context and a status chip.
/// Tapping navigates to that sibling's SIS profile.
class _SiblingRow extends StatelessWidget {
  const _SiblingRow({required this.sibling});

  final SisSibling sibling;

  (String, KpiAccent) get _statusChip => switch (sibling.status) {
        SisStudentStatus.active => ('Active', KpiAccent.success),
        SisStudentStatus.prospect => ('Prospect', KpiAccent.warning),
        SisStudentStatus.transferred => ('Transferred', KpiAccent.neutral),
        SisStudentStatus.exited => ('Exited', KpiAccent.neutral),
        SisStudentStatus.alumni => ('Alumni', KpiAccent.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final (statusLabel, statusTone) = _statusChip;

    final classLabel = (sibling.classLabel.isEmpty && sibling.section.isEmpty)
        ? null
        : 'Class ${sibling.classLabel}'
            '${sibling.section.isEmpty ? '' : '-${sibling.section}'}';
    final subtitle = [
      if (sibling.admissionNumber.isNotEmpty) sibling.admissionNumber,
      if (classLabel != null) classLabel,
    ].join(' · ');

    return InkWell(
      key: QaTestKeys.sisSiblingRow(sibling.studentId),
      onTap: () => context.go(RouteNames.sisStudentDetail(sibling.studentId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sibling.studentName, style: text.titleSmall),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
            AksharaStatusChip(label: statusLabel, tone: statusTone),
            const SizedBox(width: AksharaSpacing.s2),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

/// SIS-1 — the certificate issuance register (bonafide/study/conduct + TC),
/// newest first. Reads from [sisCertificateRegisterProvider].
class _CertificateRegister extends ConsumerWidget {
  const _CertificateRegister({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final register = ref.watch(sisCertificateRegisterProvider(studentId));

    return Material(
      key: QaTestKeys.sisCertificateRegister,
      child: register.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s3),
          child: LinearProgressIndicator(),
        ),
        error: (_, __) => Text(
          'Could not load the certificate register.',
          style: text.bodySmall,
        ),
        data: (issues) {
          if (issues.isEmpty) {
            return Text(
              'No certificates issued yet.',
              style: text.bodyMedium,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final issue in issues) _CertificateRow(issue: issue),
            ],
          );
        },
      ),
    );
  }
}

class _CertificateRow extends StatelessWidget {
  const _CertificateRow({required this.issue});

  final SisCertificateIssue issue;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final serial = issue.serialNo;
    final reason = issue.reason;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${issue.type.certificateTitle}'
                  '${serial != null && serial.isNotEmpty ? ' · $serial' : ''}',
                  style: text.titleSmall,
                ),
              ),
            ],
          ),
          Text(
            'Issued ${issue.issuedAt}'
            '${reason != null && reason.isNotEmpty ? ' · $reason' : ''}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
