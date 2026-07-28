import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reports/akshara_report_export_service.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../core/utils/phone_call_launcher.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../phase4/phase4_providers.dart';
import 'student_360_models.dart';

/// Student 360 — ONE scrolling screen, ordered for a parent meeting.
///
/// This replaced a 9-tab layout. In a parent meeting a principal cannot hunt
/// through tabs while a parent waits, so the page is ordered by what gets asked
/// first: who the child is, anything urgent (care alerts), how to reach the
/// parents, then the headline numbers, then the supporting detail. Everything
/// is on one scroll — no tab is ever hiding an answer.
///
/// HEALTH SCOPE (owner decision, LOCKED 2026-07-15): this screen shows CARE
/// ALERTS only — the minimum actionable facts ("severe peanut allergy — epipen
/// in infirmary"). It never renders clinical detail (diagnoses, medication,
/// treatment notes); that lives behind the health module's own permission and
/// audit path. Do not add clinical fields here.
class Student360Screen extends ConsumerWidget {
  const Student360Screen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(student360ProfileProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student 360'),
        actions: [
          profile.maybeWhen(
            data: (raw) => _ExportButton(
              studentId: studentId,
              data: raw as Student360Profile,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profile.when(
        data: (raw) {
          final data = raw as Student360Profile;
          final timeline = ref.watch(student360TimelineProvider(studentId));
          return _Student360Body(
            studentId: studentId,
            data: data,
            timeline: timeline,
          );
        },
        loading: () =>
            const AksharaLoadingState(semanticLabel: 'Loading student profile'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load student profile.',
          onRetry: () => ref.invalidate(student360ProfileProvider(studentId)),
        ),
      ),
    );
  }
}

class _Student360Body extends StatelessWidget {
  const _Student360Body({
    required this.studentId,
    required this.data,
    required this.timeline,
  });

  final String studentId;
  final Student360Profile data;
  final AsyncValue<dynamic> timeline;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: QaTestKeys.student360TabBar,
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        _IdentityHeader(studentId: studentId, data: data),
        const SizedBox(height: AksharaSpacing.s3),

        // Urgent first: a care alert must never be something you scroll to find.
        _CareAlerts(care: data.care),

        _ParentContacts(parentInformation: data.parentInformation),
        const SizedBox(height: AksharaSpacing.s3),

        _HeadlineMetrics(data: data),
        const SizedBox(height: AksharaSpacing.s4),

        _Section(
          title: 'Academic performance',
          icon: Icons.school_outlined,
          entries: _marksEntries(data.marks),
          emptyMessage: 'No marks published for this student yet.',
          extra: _ExamList(marks: data.marks),
        ),
        _Section(
          title: 'Attendance',
          icon: Icons.event_available_outlined,
          entries: _attendanceEntries(data.attendance),
          emptyMessage: 'No attendance recorded yet.',
        ),
        _LeaveHistory(leave: data.leave),
        _Section(
          title: 'Fees',
          icon: Icons.payments_outlined,
          entries: _feesEntries(data.fees),
          emptyMessage: 'No fee records for this student.',
        ),
        _Section(
          title: 'Transport',
          icon: Icons.directions_bus_outlined,
          entries: _transportEntries(data.transport),
          emptyMessage: 'This student does not use school transport.',
        ),
        _Section(
          title: 'Homework',
          icon: Icons.assignment_outlined,
          entries: _homeworkEntries(data.homework),
          emptyMessage: 'No homework recorded yet.',
        ),
        _Section(
          title: 'Behaviour',
          icon: Icons.psychology_outlined,
          entries: _behaviourEntries(data.behaviour),
          emptyMessage: 'No conduct records — nothing of concern on file.',
        ),
        _Section(
          title: 'Communication',
          icon: Icons.forum_outlined,
          entries: _communicationEntries(data.communication),
          emptyMessage: 'No messages exchanged with this family yet.',
        ),
        _Section(
          title: 'Documents',
          icon: Icons.folder_outlined,
          entries: _documentsEntries(data.documents),
          emptyMessage: 'No documents uploaded.',
        ),
        _Timeline(timeline: timeline),
        const SizedBox(height: AksharaSpacing.s4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — photo, name, the identifiers a principal reads out loud.
// ─────────────────────────────────────────────────────────────────────────────

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.studentId, required this.data});

  final String studentId;
  final Student360Profile data;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    final name = _name(data, studentId);
    final className = data.identity['className']?.toString() ?? '';
    final section = data.identity['sectionName']?.toString();
    final roll = data.identity['rollNumber']?.toString();
    final code = data.identity['studentCode']?.toString();
    final admissionNo = data.admissions['admissionNumber']?.toString();
    final photoUrl = data.identity['photoUrl']?.toString();

    final classLine = [
      if (className.isNotEmpty)
        section != null && section.isNotEmpty ? '$className · $section' : className,
      if (roll != null && roll.isNotEmpty) 'Roll $roll',
    ].join('  ·  ');

    return AksharaSurfaceCard(
      semanticLabel: 'Student identity',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudentPhoto(photoUrl: photoUrl, name: name),
          const SizedBox(width: AksharaSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleLarge),
                if (classLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(classLine, style: text.bodyMedium),
                ],
                const SizedBox(height: AksharaSpacing.s2),
                Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s1,
                  children: [
                    if (admissionNo != null && admissionNo.isNotEmpty)
                      _IdChip(label: 'ERP', value: admissionNo),
                    if (code != null && code.isNotEmpty)
                      _IdChip(label: 'ID', value: code),
                    if (data.identity['status'] != null)
                      AksharaStatusChip(
                        label: '${data.identity['status']}',
                        tone: '${data.identity['status']}' == 'active'
                            ? KpiAccent.success
                            : KpiAccent.neutral,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo when the school has uploaded one, initials otherwise. Never a broken
/// image box — an unset photo is a normal state, not an error.
class _StudentPhoto extends StatelessWidget {
  const _StudentPhoto({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = photoUrl;

    Widget fallback() => Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(name),
            style: context.aksharaText.titleLarge.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    if (url == null || url.isEmpty) return fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback(),
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

class _IdChip extends StatelessWidget {
  const _IdChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
      ),
      child: Text(
        '$label $value',
        style: context.aksharaText.bodySmall.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Care alerts — the only health content allowed on this surface.
// ─────────────────────────────────────────────────────────────────────────────

class _CareAlerts extends StatelessWidget {
  const _CareAlerts({required this.care});

  final Map<String, dynamic> care;

  @override
  Widget build(BuildContext context) {
    final raw = care['alerts'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final alerts = raw.whereType<Map>().toList();
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: _CareAlertTile(alert: alert),
            ),
        ],
      ),
    );
  }
}

class _CareAlertTile extends StatelessWidget {
  const _CareAlertTile({required this.alert});

  final Map<dynamic, dynamic> alert;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final severity = '${alert['severity'] ?? 'important'}';
    final label = '${alert['label'] ?? ''}';
    final note = '${alert['actionNote'] ?? ''}';

    final (accent, icon) = switch (severity) {
      'critical' => (KpiAccent.error, Icons.emergency_outlined),
      'important' => (KpiAccent.warning, Icons.health_and_safety_outlined),
      _ => (KpiAccent.neutral, Icons.info_outline),
    };
    final tone = accent.resolve(context);

    return Container(
      padding: const EdgeInsets.all(AksharaSpacing.s3),
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone.foreground),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.foreground,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parent contacts — tappable, because the next action is usually "call them".
// ─────────────────────────────────────────────────────────────────────────────

class _ParentContacts extends StatelessWidget {
  const _ParentContacts({required this.parentInformation});

  final Map<String, dynamic> parentInformation;

  @override
  Widget build(BuildContext context) {
    final guardians = parentInformation['guardians'];
    final rows = guardians is List ? guardians.whereType<Map>().toList() : const [];

    if (rows.isEmpty) {
      final fallback = parentInformation['guardianName']?.toString();
      if (fallback == null || fallback.isEmpty) return const SizedBox.shrink();
      return AksharaKeyValueCard(
        title: 'Parent / guardian',
        entries: [('Guardian', fallback)],
      );
    }

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parent / guardian', style: context.aksharaText.titleSmall),
          const SizedBox(height: AksharaSpacing.s2),
          for (final g in rows) _GuardianRow(guardian: g),
        ],
      ),
    );
  }
}

class _GuardianRow extends StatelessWidget {
  const _GuardianRow({required this.guardian});

  final Map<dynamic, dynamic> guardian;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final name = '${guardian['name'] ?? '—'}';
    final relationship = guardian['relationship']?.toString();
    final phone = guardian['phone']?.toString();
    final dialable = (phone == null || phone.isEmpty)
        ? null
        : PhoneCallLauncher.resolvePhoneDigits(phone);
    final isPrimary = guardian['isPrimary'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: text.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: AksharaSpacing.s2),
                      const AksharaStatusChip(
                        label: 'Primary',
                        tone: KpiAccent.primary,
                      ),
                    ],
                  ],
                ),
                // The number is TEXT, not a button label — a principal reads it
                // aloud at least as often as they tap it, and keeping it out of
                // the button stops a long number from overflowing the row.
                Text(
                  [
                    if (relationship != null && relationship.isNotEmpty)
                      relationship,
                    if (phone != null && phone.isNotEmpty) phone,
                  ].join('  ·  '),
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Phone is null when the caller's view mode withholds sensitive
          // fields, and unlaunchable numbers are filtered by the launcher's own
          // validity gate — so a dead "call" control is never rendered.
          if (dialable != null)
            IconButton(
              onPressed: () => PhoneCallLauncher.dial(dialable),
              icon: const Icon(Icons.call_outlined),
              tooltip: 'Call $name',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Headline metrics — the four numbers a parent meeting opens with.
// ─────────────────────────────────────────────────────────────────────────────

class _HeadlineMetrics extends StatelessWidget {
  const _HeadlineMetrics({required this.data});

  final Student360Profile data;

  @override
  Widget build(BuildContext context) {
    final attendancePct = data.attendance['percent'];
    final outstanding = data.fees['outstanding'] ??
        data.fees['pendingAmount'] ??
        data.fees['pending'];
    final homeworkRate = data.homework['completionRate'];
    final riskLevel = data.risk['riskLevel'];

    final cards = <Widget>[
      if (attendancePct != null)
        _Metric(
          value: '$attendancePct%',
          label: 'Attendance',
          accent: _attendanceAccent(attendancePct),
        ),
      if (outstanding != null)
        _Metric(
          value: '₹$outstanding',
          label: 'Fees due',
          accent: _isZero(outstanding) ? KpiAccent.success : KpiAccent.warning,
        ),
      if (homeworkRate != null)
        _Metric(
          value: '$homeworkRate%',
          label: 'Homework',
          accent: KpiAccent.primary,
        ),
      if (riskLevel != null)
        _Metric(
          value: '$riskLevel',
          label: 'Risk',
          accent: switch ('$riskLevel') {
            'high' => KpiAccent.error,
            'medium' => KpiAccent.warning,
            _ => KpiAccent.success,
          },
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

  static bool _isZero(Object? value) =>
      value == 0 || value == '0' || value == 0.0;

  static KpiAccent _attendanceAccent(Object? pct) {
    final v = pct is num ? pct.toDouble() : double.tryParse('$pct');
    if (v == null) return KpiAccent.neutral;
    if (v >= 85) return KpiAccent.success;
    if (v >= 75) return KpiAccent.warning;
    return KpiAccent.error;
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
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic section + the specialised ones.
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyMessage,
    this.extra,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> entries;
  final String emptyMessage;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: entries.isEmpty && extra == null
          ? AksharaKeyValueCard(
              titleWidget: _SectionTitle(icon: icon, title: title),
              entries: const [],
              trailing: null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AksharaKeyValueCard(
                  titleWidget: _SectionTitle(icon: icon, title: title),
                  entries: entries.isEmpty ? [('', emptyMessage)] : entries,
                ),
                if (extra != null) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  extra!,
                ],
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

class _ExamList extends StatelessWidget {
  const _ExamList({required this.marks});

  final Map<String, dynamic> marks;

  @override
  Widget build(BuildContext context) {
    final exams = marks['exams'];
    if (exams is! List || exams.isEmpty) return const SizedBox.shrink();

    return AksharaSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s2,
      ),
      child: Column(
        children: [
          for (final exam in exams.whereType<Map>())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${exam['exam'] ?? '—'}',
                      style: context.aksharaText.bodyMedium,
                    ),
                  ),
                  Text(
                    '${exam['averagePercent'] ?? '—'}%',
                    style: context.aksharaText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LeaveHistory extends StatelessWidget {
  const _LeaveHistory({required this.leave});

  final Map<String, dynamic> leave;

  @override
  Widget build(BuildContext context) {
    final raw = leave['items'];
    final items = raw is List ? raw.whereType<Map>().toList() : const [];

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AksharaSpacing.s3),
        child: AksharaKeyValueCard(
          title: 'Leave history',
          entries: [('', 'No leave applied for this student.')],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.beach_access_outlined,
              title: 'Leave history',
            ),
            const SizedBox(height: AksharaSpacing.s2),
            for (final item in items) _LeaveRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.item});

  final Map<dynamic, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final from = '${item['fromDate'] ?? ''}';
    final to = '${item['toDate'] ?? ''}';
    final range = from == to ? from : '$from → $to';
    final status = '${item['status'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$range  ·  ${item['type'] ?? ''}',
                  style: text.bodyMedium,
                ),
                if ('${item['reason'] ?? ''}'.isNotEmpty)
                  Text('${item['reason']}', style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          AksharaStatusChip(
            label: status,
            tone: switch (status) {
              'approved' => KpiAccent.success,
              'rejected' => KpiAccent.error,
              'pending' => KpiAccent.warning,
              _ => KpiAccent.neutral,
            },
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.timeline});

  final AsyncValue<dynamic> timeline;

  @override
  Widget build(BuildContext context) {
    return timeline.when(
      data: (rawEvents) {
        final events = (rawEvents as List).cast<StudentTimelineEvent>();
        if (events.isEmpty) {
          return const _TimelineNote('No activity recorded for this student yet.');
        }
        return AksharaSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(icon: Icons.history, title: 'Recent activity'),
              const SizedBox(height: AksharaSpacing.s2),
              for (final event in events)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: context.aksharaText.bodyMedium,
                            ),
                            Text(
                              '${event.sourceModule} · ${event.eventAt}',
                              style: context.aksharaText.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading timeline'),
      // Honest state: vanishing on error let a principal read "failed to load"
      // as "nothing has happened with this child". Every other section on this
      // screen says what it knows — so does this one.
      error: (e, _) => const _TimelineNote(
        'Recent activity could not be loaded. Reopen this profile to try again.',
      ),
    );
  }
}

/// The "Recent activity" card with a single honest line instead of events —
/// used for both "nothing recorded" and "could not load", which must never be
/// confused with each other or with the section not existing.
class _TimelineNote extends StatelessWidget {
  const _TimelineNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.history, title: 'Recent activity'),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            message,
            style: context.aksharaText.bodySmall.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends ConsumerWidget {
  const _ExportButton({required this.studentId, required this.data});

  final String studentId;
  final Student360Profile data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: QaTestKeys.student360ExportButton,
      tooltip: 'Export dossier',
      icon: const Icon(Icons.picture_as_pdf_outlined),
      onPressed: () async {
        final service = ref.read(aksharaReportExportServiceProvider);
        final name = _name(data, studentId);
        final bytes = await service.buildTabularReportPdf(
          reportTitle: 'Student 360 Dossier',
          moduleLabel: 'SIS · $name',
          generatedAtLabel: DateTime.now().toIso8601String(),
          rows: [
            MapEntry('Student ID', studentId),
            MapEntry('Name', name),
            MapEntry(
              'Class',
              '${data.identity['className'] ?? ''} ${data.identity['sectionName'] ?? ''}'
                  .trim(),
            ),
            MapEntry('Attendance %', '${data.attendance['percent'] ?? '—'}'),
            MapEntry('Fee paid %', '${data.fees['paidPercent'] ?? '—'}'),
            MapEntry('Risk level', '${data.risk['riskLevel'] ?? '—'}'),
          ],
        );
        if (!context.mounted) return;
        await service.previewPdf(
          documentName: 'student_360_$studentId.pdf',
          bytes: bytes,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: QaTestKeys.student360ExportSuccessSnackbar,
            content: Text('Student 360 dossier PDF ready'),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field extraction. Tolerant of both the API and mock payload shapes.
// ─────────────────────────────────────────────────────────────────────────────

String _name(Student360Profile data, String studentId) =>
    data.identity['name']?.toString() ??
    data.identity['displayName']?.toString() ??
    studentId;

List<(String, String)> _attendanceEntries(Map<String, dynamic> data) {
  final pct = data['percent'] ?? data['attendancePercent'];
  return [
    if (pct != null) ('Attendance rate', '$pct%'),
    if (data['present'] != null) ('Present days', '${data['present']}'),
    if (data['presentDays'] != null) ('Present days', '${data['presentDays']}'),
    if (data['absent'] != null) ('Absent days', '${data['absent']}'),
    if (data['absentDays'] != null) ('Absent days', '${data['absentDays']}'),
    if (data['total'] != null) ('Days marked', '${data['total']}'),
  ];
}

List<(String, String)> _marksEntries(Map<String, dynamic> data) {
  final avg = data['average'] ?? data['averageMarks'];
  final exams = data['exams'];
  return [
    if (avg != null) ('Average marks', '$avg%'),
    if (data['subjectsAssessed'] != null)
      ('Subjects assessed', '${data['subjectsAssessed']}'),
    if (data['trend'] != null) ('Trend', '${data['trend']}'),
    if (exams is List) ('Exams published', '${exams.length}'),
  ];
}

List<(String, String)> _homeworkEntries(Map<String, dynamic> data) {
  final rate = data['completionRate'] ?? data['homeworkCompletionRate'];
  return [
    if (rate != null) ('Completion rate', '$rate%'),
    if (data['submitted'] != null && data['total'] != null)
      ('Submitted', '${data['submitted']}/${data['total']}'),
    if (data['pendingCount'] != null)
      ('Pending assignments', '${data['pendingCount']}'),
  ];
}

List<(String, String)> _feesEntries(Map<String, dynamic> data) {
  final outstanding =
      data['outstanding'] ?? data['pendingAmount'] ?? data['pending'];
  return [
    if (outstanding != null) ('Outstanding', '₹$outstanding'),
    if (data['paidPercent'] != null) ('Paid', '${data['paidPercent']}%'),
    if (data['openInvoices'] != null)
      ('Open invoices', '${data['openInvoices']}'),
  ];
}

List<(String, String)> _behaviourEntries(Map<String, dynamic> data) {
  final incidents = data['incidents'];
  return [
    if (data['conductScore'] != null)
      ('Conduct score', '${data['conductScore']}'),
    if (incidents is List) ('Incidents on file', '${incidents.length}'),
    if (data['remarks'] != null) ('Remarks', '${data['remarks']}'),
  ];
}

List<(String, String)> _transportEntries(Map<String, dynamic> data) {
  return [
    if (data['routeName'] != null) ('Route', '${data['routeName']}'),
    if (data['stopName'] != null) ('Stop', '${data['stopName']}'),
    if (data['vehicleNumber'] != null) ('Bus', '${data['vehicleNumber']}'),
    if (data['pickupTime'] != null) ('Pickup', '${data['pickupTime']}'),
    if (data['dropTime'] != null) ('Drop-off', '${data['dropTime']}'),
  ];
}

List<(String, String)> _communicationEntries(Map<String, dynamic> data) {
  return [
    if (data['pendingNotices'] != null)
      ('Pending notices', '${data['pendingNotices']}'),
    if (data['unreadMessages'] != null)
      ('Unread messages', '${data['unreadMessages']}'),
    if (data['threadCount'] != null) ('Conversations', '${data['threadCount']}'),
    if (data['lastContactAt'] != null)
      ('Last contact', '${data['lastContactAt']}'),
  ];
}

List<(String, String)> _documentsEntries(Map<String, dynamic> data) {
  final items = data['items'];
  if (items is! List || items.isEmpty) return const [];
  final verified =
      items.where((item) => item is Map && item['status'] == 'verified').length;
  return [
    ('Documents on file', '${items.length}'),
    ('Verified', '$verified'),
  ];
}
