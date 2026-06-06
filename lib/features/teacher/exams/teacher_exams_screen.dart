import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_models.dart';
import 'teacher_exams_provider.dart';

/// Teacher exams — TA-05.
class TeacherExamsScreen extends ConsumerWidget {
  const TeacherExamsScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherExamsProvider);
    final section = ref.watch(teacherExamSectionProvider);
    final isLoading = ref.watch(teacherExamsLoadingProvider);
    final hasError = ref.watch(teacherExamsErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Exams',
        subtitle: 'Priya Sharma · Mathematics',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load exam data.',
                  onRetry: () =>
                      ref.read(teacherExamsErrorProvider.notifier).state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= _tabletBreakpoint;
                    final pad = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? _tabletMaxContentWidth
                              : double.infinity,
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            AksharaSpacing.s4,
                            pad,
                            AksharaSpacing.s6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 88,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.upcomingExams.length}',
                                        subtitle: 'Upcoming',
                                        accent: KpiAccent.primary,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.classAveragePercent}%',
                                        subtitle: 'Class avg',
                                        accent: KpiAccent.success,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value:
                                            '${data.markEntries.where((m) => m.marksObtained == null).length}',
                                        subtitle: 'Pending marks',
                                        accent: KpiAccent.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              Semantics(
                                label: 'Exam section selector',
                                child: SegmentedButton<TeacherExamSection>(
                                  segments: [
                                    for (final s in TeacherExamSection.values)
                                      ButtonSegment(
                                        value: s,
                                        label: Text(s.label),
                                      ),
                                  ],
                                  selected: {section},
                                  showSelectedIcon: false,
                                  onSelectionChanged: (v) => ref
                                      .read(teacherExamSectionProvider.notifier)
                                      .state = v.first,
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              switch (section) {
                                TeacherExamSection.upcoming =>
                                  _UpcomingList(exams: data.upcomingExams),
                                TeacherExamSection.marksEntry =>
                                  _MarksEntryList(entries: data.markEntries),
                                TeacherExamSection.results => AksharaInsightCard(
                                    message:
                                        'Class average is ${data.classAveragePercent}% for Unit Test — Mathematics.',
                                    actionLabel: 'View report',
                                    onAction: () {},
                                  ),
                              },
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.exams});
  final List<TeacherUpcomingExam> exams;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return const AksharaEmptyState(
        message: 'No upcoming exams.',
        compact: true,
      );
    }

    final colors = context.colors;
    final text = context.aksharaText;

    return Column(
      children: [
        for (var i = 0; i < exams.length; i++) ...[
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AksharaRadius.card,
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: ListTile(
              title: Text(exams[i].title, style: text.titleSmall),
              subtitle: Text(
                '${exams[i].classLabel} · ${exams[i].dateLabel} · Max ${exams[i].maxMarks}',
              ),
            ),
          ),
          if (i < exams.length - 1)
            const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}

class _MarksEntryList extends ConsumerWidget {
  const _MarksEntryList({required this.entries});
  final List<ExamMarkEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const AksharaEmptyState(
        message: 'No students for marks entry.',
        compact: true,
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          ListTile(
            title: Text(entry.studentName),
            subtitle: Text('Roll ${entry.rollNo}'),
            trailing: SizedBox(
              width: 72,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '/${entry.maxMarks}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                controller: TextEditingController(
                  text: entry.marksObtained?.toString() ?? '',
                ),
                onSubmitted: (value) {
                  final marks = int.tryParse(value);
                  if (marks != null) {
                    updateExamMark(ref, entry.id, marks);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}
