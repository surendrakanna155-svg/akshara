import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../core/utils/phone_call_launcher.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../hr_models.dart';
import '../hr_providers.dart';

/// Staff 360 — one scrolling dossier for any employee, teaching or not.
///
/// The counterpart to Student 360, built on the same conviction: a principal in
/// a conversation cannot hunt through tabs. Ordered by what gets asked first —
/// who they are, how to reach them, are they here today, what are they carrying
/// — then the supporting detail.
///
/// **Teacher 360 is this screen.** A teacher is an employee whose role happens
/// to be teaching, so rather than fork a near-identical screen, the teaching
/// sections (class teacher assignment, app link) appear only when the employee
/// actually teaches. One screen to maintain, no drift between two copies.
///
/// Sections with no data render an honest empty line rather than being hidden,
/// so a principal can tell "nothing recorded" apart from "this school does not
/// track that" — the honest-state doctrine the product is held to everywhere.
class Staff360Screen extends ConsumerWidget {
  const Staff360Screen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrEmployeeProfileLoadingProvider);
    final isError = ref.watch(hrEmployeeProfileErrorProvider);
    final detail = ref.watch(hrEmployeeDetailProvider(employeeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Staff 360')),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const AksharaLoadingState(semanticLabel: 'Loading staff profile');
          }
          if (isError || detail == null) {
            return AksharaErrorState(
              message: 'Unable to load this staff profile.',
              onRetry: () => ref.invalidate(hrEmployeeDetailProvider(employeeId)),
            );
          }
          return _Staff360Body(detail: detail);
        },
      ),
    );
  }
}

class _Staff360Body extends StatelessWidget {
  const _Staff360Body({required this.detail});

  final HrEmployeeDetail detail;

  @override
  Widget build(BuildContext context) {
    final e = detail.employee;
    final teaches = e.role == HrEmployeeRole.teacher ||
        (e.classLabel != null && e.classLabel!.isNotEmpty);

    return ListView(
      key: QaTestKeys.staff360Body,
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        _StaffHeader(employee: e),
        const SizedBox(height: AksharaSpacing.s3),

        _ContactCard(detail: detail),
        const SizedBox(height: AksharaSpacing.s3),

        _StaffMetrics(detail: detail),
        const SizedBox(height: AksharaSpacing.s4),

        if (teaches) ...[
          AksharaKeyValueCard(
            titleWidget: const _SectionTitle(
              icon: Icons.menu_book_outlined,
              title: 'Teaching',
            ),
            entries: [
              if ((e.classLabel ?? '').isNotEmpty)
                ('Class teacher of', e.classLabel!),
              ('Teacher app', e.teacherAppLinked == true ? 'Linked' : 'Not linked'),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
        ],

        AksharaKeyValueCard(
          titleWidget: const _SectionTitle(
            icon: Icons.badge_outlined,
            title: 'Employment',
          ),
          entries: [
            ('Designation', e.designation.isEmpty ? '—' : e.designation),
            ('Department', e.department.label),
            ('Role', e.role.label),
            ('Joined', e.joinDate.isEmpty ? '—' : e.joinDate),
            ('Employee code', e.employeeCode.isEmpty ? '—' : e.employeeCode),
            if (detail.reportingManager.isNotEmpty)
              ('Reports to', detail.reportingManager),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),

        _LeaveBalances(balances: detail.leaveBalances),
        _RecentAttendance(records: detail.recentAttendance),
        _Documents(documents: detail.documents),

        if (detail.integrationNotes.isNotEmpty) ...[
          AksharaKeyValueCard(
            titleWidget: const _SectionTitle(
              icon: Icons.link_outlined,
              title: 'Integrations',
            ),
            entries: [
              for (final note in detail.integrationNotes) ('', note),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
        ],
        const SizedBox(height: AksharaSpacing.s4),
      ],
    );
  }
}

class _StaffHeader extends StatelessWidget {
  const _StaffHeader({required this.employee});

  final HrEmployee employee;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return AksharaSurfaceCard(
      semanticLabel: 'Staff identity',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff photos are not stored yet (same position students were in
          // before the SIS-documents route). Initials keep the dossier looking
          // finished instead of showing a broken image frame.
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(employee.name),
              style: text.titleLarge.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name, style: text.titleLarge),
                if (employee.designation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${employee.designation} · ${employee.department.label}',
                    style: text.bodyMedium,
                  ),
                ],
                const SizedBox(height: AksharaSpacing.s2),
                AksharaStatusChip(
                  label: employee.status.label,
                  tone: employee.status == HrEmployeeStatus.active
                      ? KpiAccent.success
                      : KpiAccent.neutral,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.detail});

  final HrEmployeeDetail detail;

  @override
  Widget build(BuildContext context) {
    final e = detail.employee;
    final dialable = e.phone.isEmpty
        ? null
        : PhoneCallLauncher.resolvePhoneDigits(e.phone);

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.contacts_outlined, title: 'Contact'),
          const SizedBox(height: AksharaSpacing.s2),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (e.phone.isNotEmpty) e.phone,
                        if (e.email.isNotEmpty) e.email,
                      ].join('  ·  '),
                      style: context.aksharaText.bodyMedium,
                    ),
                    if (detail.emergencyContact.isNotEmpty)
                      Text(
                        'Emergency: ${detail.emergencyContact}',
                        style: context.aksharaText.bodySmall,
                      ),
                    if (detail.address.isNotEmpty)
                      Text(detail.address, style: context.aksharaText.bodySmall),
                  ],
                ),
              ),
              if (dialable != null)
                IconButton(
                  onPressed: () => PhoneCallLauncher.dial(dialable),
                  icon: const Icon(Icons.call_outlined),
                  tooltip: 'Call ${e.name}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The three numbers a principal wants before starting a conversation with a
/// staff member: are they in today, how much leave is left, what is expiring.
class _StaffMetrics extends StatelessWidget {
  const _StaffMetrics({required this.detail});

  final HrEmployeeDetail detail;

  @override
  Widget build(BuildContext context) {
    final present = detail.recentAttendance
        .where((r) => r.status == HrAttendanceStatus.present)
        .length;
    final total = detail.recentAttendance.length;
    final leaveAvailable =
        detail.leaveBalances.fold<int>(0, (sum, b) => sum + b.available);
    final expiring = detail.documents
        .where((d) => (d.daysToExpiry ?? 999) <= 30)
        .length;

    final cards = <Widget>[
      if (total > 0)
        _Metric(
          value: '$present/$total',
          label: 'Recent present',
          accent: present == total ? KpiAccent.success : KpiAccent.warning,
        ),
      // Honest state: with no leave policy configured there is no balance to
      // report. A "0 Leave days left" would read as "this employee has used up
      // their leave" AND contradict the "No leave balances recorded." line
      // further down this very screen. Gated like its two siblings.
      if (detail.leaveBalances.isNotEmpty)
        _Metric(
          value: '$leaveAvailable',
          label: 'Leave days left',
          accent: KpiAccent.primary,
        ),
      if (detail.documents.isNotEmpty)
        _Metric(
          value: '$expiring',
          label: 'Docs expiring',
          accent: expiring > 0 ? KpiAccent.error : KpiAccent.success,
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AksharaSpacing.s2),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final KpiAccent accent;

  @override
  Widget build(BuildContext context) {
    final tone = accent.resolve(context);
    final text = context.aksharaText;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AksharaSpacing.s3,
        horizontal: AksharaSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      ),
      child: Column(
        children: [
          // Never wrap a metric number — same rule as the KPI cards.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: text.titleMedium.copyWith(
                color: tone.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

class _LeaveBalances extends StatelessWidget {
  const _LeaveBalances({required this.balances});

  final List<HrEmployeeLeaveBalance> balances;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaKeyValueCard(
        titleWidget: const _SectionTitle(
          icon: Icons.beach_access_outlined,
          title: 'Leave balances',
        ),
        entries: balances.isEmpty
            ? const [('', 'No leave balances recorded.')]
            : [
                for (final b in balances)
                  (b.leaveType.label, '${b.available} left · ${b.used} used'),
              ],
      ),
    );
  }
}

class _RecentAttendance extends StatelessWidget {
  const _RecentAttendance({required this.records});

  final List<HrAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaKeyValueCard(
        titleWidget: const _SectionTitle(
          icon: Icons.event_available_outlined,
          title: 'Recent attendance',
        ),
        entries: records.isEmpty
            ? const [('', 'No attendance recorded yet.')]
            : [
                for (final r in records.take(8))
                  (
                    r.date,
                    '${r.status.label}'
                        '${r.checkIn.isNotEmpty ? ' · in ${r.checkIn}' : ''}'
                        '${r.checkOut.isNotEmpty ? ' · out ${r.checkOut}' : ''}',
                  ),
              ],
      ),
    );
  }
}

class _Documents extends StatelessWidget {
  const _Documents({required this.documents});

  final List<HrEmployeeDocument> documents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaKeyValueCard(
        titleWidget: const _SectionTitle(
          icon: Icons.folder_outlined,
          title: 'Documents',
        ),
        entries: documents.isEmpty
            ? const [('', 'No documents on file.')]
            : [
                for (final d in documents)
                  (
                    d.title,
                    d.daysToExpiry != null && d.daysToExpiry! <= 30
                        ? '${d.status} · expires in ${d.daysToExpiry}d'
                        : d.status,
                  ),
              ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: AksharaSpacing.s2),
        Text(title, style: context.aksharaText.titleSmall),
      ],
    );
  }
}
