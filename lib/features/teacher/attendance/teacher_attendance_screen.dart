import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'attendance_models.dart';
import 'teacher_attendance_provider.dart';
import 'teacher_attendance_workflow.dart';
import 'widgets/class_selector_strip.dart';
import 'widgets/student_attendance_row.dart';

/// Teacher attendance marking — TA-02.
class TeacherAttendanceScreen extends ConsumerWidget {
  const TeacherAttendanceScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherAttendanceProvider);
    final isLoading = ref.watch(teacherAttendanceLoadingProvider);
    final hasError = ref.watch(teacherAttendanceErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Mark Attendance',
        subtitle: 'Priya Sharma · Mathematics',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading attendance')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load attendance roster.',
                  onRetry: () => ref
                      .read(teacherAttendanceErrorProvider.notifier)
                      .state = false,
                )
              : data.classes.isEmpty
                  ? const AksharaEmptyState(
                      message: 'No classes scheduled for attendance.',
                      icon: Icons.class_outlined,
                    )
                  : _AttendanceBody(data: data),
    );
  }
}

class _AttendanceBody extends ConsumerWidget {
  const _AttendanceBody({required this.data});

  final TeacherAttendanceData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >=
            TeacherAttendanceScreen._tabletBreakpoint;
        final horizontalPadding = isTablet
            ? AksharaSpacing.tabletMargin
            : AksharaSpacing.mobileMargin;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet
                  ? TeacherAttendanceScreen._tabletMaxContentWidth
                  : double.infinity,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AksharaSpacing.s4,
                    horizontalPadding,
                    AksharaSpacing.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClassSelectorStrip(
                        classes: data.classes,
                        selectedClassId: data.selectedClassId,
                        onClassSelected: (id) => ref
                            .read(teacherAttendanceClassProvider.notifier)
                            .state = id,
                      ),
                      const SizedBox(height: AksharaSpacing.s3),
                      _AttendanceKpiRow(data: data),
                      if (data.draftSavedAt != null) ...[
                        const SizedBox(height: AksharaSpacing.s2),
                        AksharaWarningBanner(
                          message: 'Draft saved at ${data.draftSavedAt}',
                        ),
                      ],
                      if (data.isSubmitted) ...[
                        const SizedBox(height: AksharaSpacing.s2),
                        const AksharaWarningBanner(
                          key: QaTestKeys.teacherAttendanceSubmittedBanner,
                          message: 'Attendance submitted successfully.',
                        ),
                        const SizedBox(height: AksharaSpacing.s2),
                        AksharaViewAction(
                          permission: Permission.submitAttendanceCorrection,
                          child: OutlinedButton.icon(
                            key: QaTestKeys.teacherAttendanceCorrectionButton,
                            onPressed: () => showAttendanceCorrectionDialog(
                              context,
                              ref,
                              data: data,
                            ),
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Request correction'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AksharaSpacing.s3),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => applyBulkMark(
                                ref,
                                StudentAttendanceMark.present,
                              ),
                              child: const Text('All present'),
                            ),
                          ),
                          const SizedBox(width: AksharaSpacing.s2),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => applyBulkMark(
                                ref,
                                StudentAttendanceMark.absent,
                              ),
                              child: const Text('All absent'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    itemCount: data.students.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.colors.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final student = data.students[index];
                      return StudentAttendanceRow(
                        student: student,
                        enabled: !data.isSubmitted,
                        onMarkChanged: (mark) => updateStudentMark(
                          ref,
                          studentId: student.id,
                          mark: mark,
                        ),
                      );
                    },
                  ),
                ),
                _AttendanceActionBar(
                  horizontalPadding: horizontalPadding,
                  canSubmit: data.unmarkedCount == 0 && !data.isSubmitted,
                  unmarkedCount: data.unmarkedCount,
                  onSaveDraft: () => saveAttendanceDraft(ref),
                  onSubmit: () async {
                    final ok = await submitAttendance(ref);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mark all students before submitting.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttendanceKpiRow extends StatelessWidget {
  const _AttendanceKpiRow({required this.data});

  final TeacherAttendanceData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${data.presentCount}',
              subtitle: 'Present',
              accent: KpiAccent.success,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.absentCount}',
              subtitle: 'Absent',
              accent: KpiAccent.error,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.lateCount}',
              subtitle: 'Late',
              accent: KpiAccent.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceActionBar extends StatelessWidget {
  const _AttendanceActionBar({
    required this.horizontalPadding,
    required this.canSubmit,
    required this.unmarkedCount,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final double horizontalPadding;
  final bool canSubmit;
  final int unmarkedCount;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AksharaSpacing.s3,
            horizontalPadding,
            AksharaSpacing.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSaveDraft,
                  child: const Text('Save draft'),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: FilledButton(
                  key: QaTestKeys.teacherAttendanceSubmitButton,
                  onPressed: canSubmit ? onSubmit : null,
                  child: Text(
                    unmarkedCount > 0
                        ? '$unmarkedCount unmarked'
                        : 'Submit',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
