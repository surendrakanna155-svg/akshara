import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../academics/timetable/substitutions/daily_substitutions_provider.dart';
import '../../academics/timetable/timetable_models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'teacher_today_provider.dart';

/// A teacher's classes for today, including any cover assigned to them.
class TeacherTodayScreen extends ConsumerWidget {
  const TeacherTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(teacherTodayScheduleProvider);
    final cover = ref.watch(teacherTodayCoverProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Today's classes")),
      // DS V2 P4 — premium persona canvas behind today's classes.
      body: AksharaPremiumBackground(
        showMotif: false,
        // A FAILED cover read is not "nothing scheduled" — falling through to
        // the empty state would hide an assigned substitution entirely, so the
        // error is carried into the list where the banner can surface it.
        child: periods.isEmpty &&
                !cover.hasError &&
                cover.valueOrNull?.isEmpty != false
            ? const AksharaEmptyState(
                icon: Icons.event_available_outlined,
                message: 'No classes scheduled for you today.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                itemCount: periods.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AksharaSpacing.s3),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CoverBanner(
                      cover: cover,
                      onRetry: () => ref.invalidate(dailySubstitutionsProvider),
                    );
                  }
                  final i = index - 1;
                  final p = periods[i];
                  return Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AksharaRadius.card,
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    child: InkWell(
                      // TCH-1 — tapping a period jumps to attendance marking with
                      // this class pre-selected.
                      borderRadius: AksharaRadius.card,
                      onTap: () => context.go(
                        '${RouteNames.teacherAttendance}'
                        '?class=${Uri.encodeQueryComponent(p.classLabel)}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AksharaSpacing.s3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p.periodLabel} · ${p.classLabel}',
                                      style: text.titleSmall),
                                  const SizedBox(height: 2),
                                  Text(p.subject,
                                      style: text.bodySmall.copyWith(
                                          color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (p.isSubstitute)
                              AksharaStatusChip(
                                label: 'Covering ${p.originalTeacherName}',
                                tone: KpiAccent.warning,
                              ),
                            const SizedBox(width: AksharaSpacing.s2),
                            Icon(Icons.chevron_right,
                                color: colors.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// TCH-4 — "Today's cover" banner: the real, server-resolved substitutions the
/// logged-in teacher is covering for the selected date. Renders nothing when the
/// teacher has no cover assigned — but a FAILED read is surfaced, never hidden:
/// silently dropping it lets a teacher miss a class they were assigned to cover.
class _CoverBanner extends StatelessWidget {
  const _CoverBanner({required this.cover, this.onRetry});

  final AsyncValue<List<TimetableSubstitution>> cover;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return cover.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => AksharaWarningBanner(
        key: const Key('teacher_today_cover_error'),
        height: 72,
        compactMessage: true,
        message: "Couldn't check today's cover. If you have been assigned a "
            'substitution it will not be listed.',
        actionLabel: onRetry == null ? null : 'Retry',
        onAction: onRetry,
        semanticLabel: "Couldn't check today's cover. If you have been "
            'assigned a substitution it will not be listed.',
      ),
      data: (subs) {
        if (subs.isEmpty) return const SizedBox.shrink();
        return Container(
          key: QaTestKeys.teacherTodayCoverBanner,
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: AksharaRadius.card,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz_outlined,
                      size: 18, color: colors.onTertiaryContainer),
                  const SizedBox(width: AksharaSpacing.s2),
                  Text("Today's cover", style: text.titleSmall),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              for (final s in subs)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _coverLine(s),
                    style:
                        text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _coverLine(TimetableSubstitution s) {
    final parts = <String>[
      if (s.periodNumber != null) 'Period ${s.periodNumber}',
      if (s.subjectLabel != null && s.subjectLabel!.isNotEmpty) s.subjectLabel!,
    ];
    final label = parts.isEmpty ? 'A period' : parts.join(' · ');
    return 'Substitute: you are covering $label.';
  }
}
