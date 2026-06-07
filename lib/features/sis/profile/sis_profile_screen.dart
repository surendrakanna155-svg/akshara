import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../sis_navigation.dart';
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
    final profile = viewState.data ?? ref.watch(sisStudentProfileProvider(studentId));

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
          profile: loadedProfile,
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context, {
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
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _DetailSection(title: 'Student details', child: _StudentDetails(student)),
          _DetailSection(title: 'Parent details', child: _ParentDetails(profile.parent)),
          if (profile.feeAccount != null)
            _DetailSection(
              title: 'Fee account summary',
              child: _FeeSummary(account: profile.feeAccount!),
            ),
          _DetailSection(
            title: 'Academic history',
            child: _AcademicHistory(entries: profile.academicHistory),
          ),
          _DetailSection(
            title: 'Documents',
            child: _DocumentsList(documents: profile.documents),
          ),
          _DetailSection(
            title: 'Timeline',
            child: _Timeline(events: profile.timeline),
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
                child: Column(
                  children: [
                    _DetailSection(
                      title: 'Academic history',
                      child: _AcademicHistory(entries: profile.academicHistory),
                    ),
                    _DetailSection(
                      title: 'Attendance summary',
                      child: _AttendanceSummary(summary: profile.attendance),
                    ),
                    _DetailSection(
                      title: 'Documents',
                      child: _DocumentsList(documents: profile.documents),
                    ),
                    _DetailSection(
                      title: 'Timeline',
                      child: _Timeline(events: profile.timeline),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _statusLabel(SisStudentStatus status) => switch (status) {
        SisStudentStatus.active => 'Active',
        SisStudentStatus.prospect => 'Prospect',
        SisStudentStatus.transferred => 'Transferred',
        SisStudentStatus.exited => 'Exited',
        SisStudentStatus.alumni => 'Alumni',
      };
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
        Text('${parent.relationship} · ${parent.phone}', style: text.bodyMedium),
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
          tone: account.status == 'Overdue'
              ? KpiAccent.error
              : KpiAccent.success,
        ),
      ],
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({required this.summary});

  final SisAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${summary.presentPercent} present (${summary.periodLabel})',
          style: text.bodyMedium,
        ),
        Text('Absent days: ${summary.absentDays}', style: text.bodyMedium),
        Text('Late arrivals: ${summary.lateDays}', style: text.bodyMedium),
      ],
    );
  }
}

class _AcademicHistory extends StatelessWidget {
  const _AcademicHistory({required this.entries});

  final List<SisAcademicHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
            title: Text('${entry.academicYear} · Class ${entry.classLabel}-${entry.section}'),
            subtitle: Text(entry.result),
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.documents});

  final List<SisDocumentSummary> documents;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          for (final doc in documents)
            ListTile(
              title: Text(doc.type),
              subtitle: Text('${doc.status} · ${doc.uploadedAt}'),
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<SisTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Student timeline, ${events.length} events',
      child: Material(
        child: Column(
          children: [
            for (final event in events)
              ListTile(
                leading: const Icon(Icons.circle, size: 8),
                title: Text(event.title),
                subtitle: Text('${event.dateLabel} · ${event.detail}'),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}
