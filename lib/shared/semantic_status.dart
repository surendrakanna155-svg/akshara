import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Semantic status colors for chips and badges across apps.
class SemanticStatusColors {
  const SemanticStatusColors({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

/// Teacher class schedule row status (TA-01).
enum ClassScheduleStatus { done, now, upcoming }

/// Student period pill state (ST-01).
enum PeriodState { now, next, later }

/// Student dashboard KPI tone.
enum StudentKpiTone { success, warning, primary, neutral }

extension ClassScheduleStatusColors on ClassScheduleStatus {
  SemanticStatusColors resolve(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (this) {
      ClassScheduleStatus.done => SemanticStatusColors(
          label: 'Done',
          background: ext.successContainer,
          foreground: ext.success,
        ),
      ClassScheduleStatus.now => SemanticStatusColors(
          label: 'Now',
          background: colors.primaryContainer,
          foreground: colors.primary,
        ),
      ClassScheduleStatus.upcoming => SemanticStatusColors(
          label: 'Upcoming',
          background: colors.surfaceContainerLow,
          foreground: colors.onSurfaceVariant,
        ),
    };
  }
}

extension PeriodStateStyle on PeriodState {
  String get label => switch (this) {
        PeriodState.now => 'Now',
        PeriodState.next => 'Next',
        PeriodState.later => 'Later',
      };

  ({Color background, Color border, double borderWidth}) resolveSurface(
    BuildContext context,
  ) {
    final colors = context.colors;

    return switch (this) {
      PeriodState.now => (
          background: colors.primaryContainer,
          border: colors.primary,
          borderWidth: 2.0,
        ),
      PeriodState.next => (
          background: colors.surface,
          border: colors.outlineVariant,
          borderWidth: 1.0,
        ),
      PeriodState.later => (
          background: colors.surface.withValues(alpha: 0.6),
          border: colors.outlineVariant,
          borderWidth: 1.0,
        ),
    };
  }

  Color resolveStateTextColor(BuildContext context) {
    final colors = context.colors;
    return this == PeriodState.now
        ? colors.primary
        : colors.onSurfaceVariant;
  }
}

extension StudentKpiToneMapping on StudentKpiTone {
  KpiAccent get kpiAccent => switch (this) {
        StudentKpiTone.success => KpiAccent.success,
        StudentKpiTone.warning => KpiAccent.warning,
        StudentKpiTone.primary => KpiAccent.primary,
        StudentKpiTone.neutral => KpiAccent.neutral,
      };

  ({Color container, Color foreground, Color border}) resolveQuickAction(
    BuildContext context,
  ) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (this) {
      StudentKpiTone.primary => (
          container: colors.primaryContainer,
          foreground: colors.primary,
          border: colors.primary.withValues(alpha: 0.4),
        ),
      StudentKpiTone.warning => (
          container: ext.warningContainer,
          foreground: ext.warning,
          border: ext.warning.withValues(alpha: 0.4),
        ),
      StudentKpiTone.success => (
          container: ext.successContainer,
          foreground: ext.success,
          border: ext.success.withValues(alpha: 0.4),
        ),
      StudentKpiTone.neutral => (
          container: colors.surfaceContainerLow,
          foreground: colors.onSurfaceVariant,
          border: colors.outlineVariant,
        ),
    };
  }
}
