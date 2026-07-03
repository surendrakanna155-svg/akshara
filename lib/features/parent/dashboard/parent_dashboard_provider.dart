import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/school_config/school_configuration_provider.dart';
import '../../../core/school_config/school_dashboard_adapter.dart';
import '../parent_active_child_provider.dart';

/// Mock dashboard payload for [ParentDashboardScreen] (PA-01).
@immutable
class ParentDashboardData {
  const ParentDashboardData({
    required this.childName,
    required this.childClass,
    required this.greetingEyebrow,
    required this.greetingHeadline,
    required this.schoolName,
    required this.statusChips,
    required this.quickActions,
    required this.todaySummary,
    required this.notices,
    required this.events,
    required this.aiInsight,
    required this.unreadNotifications,
  });

  final String childName;
  final String childClass;
  final String greetingEyebrow;
  final String greetingHeadline;
  final String schoolName;
  final List<DashboardStatusChip> statusChips;
  final List<DashboardQuickAction> quickActions;
  final List<TodaySummaryItem> todaySummary;
  final List<DashboardNotice> notices;
  final List<DashboardEvent> events;
  final DashboardAiInsight aiInsight;
  final int unreadNotifications;

  factory ParentDashboardData.mock() {
    return const ParentDashboardData(
      childName: 'Ravi Kumar',
      childClass: '8-A',
      greetingEyebrow: 'Good morning',
      greetingHeadline: "Ravi's Day at a Glance",
      schoolName: 'Akshara Public School',
      unreadNotifications: 2,
      statusChips: [
        DashboardStatusChip(
          label: 'Present',
          tone: DashboardChipTone.success,
        ),
        DashboardStatusChip(
          label: '₹4,200 due',
          tone: DashboardChipTone.warning,
        ),
        DashboardStatusChip(
          label: '2 msgs',
          tone: DashboardChipTone.primary,
        ),
      ],
      quickActions: [
        DashboardQuickAction(
          id: 'pay_fee',
          label: 'Pay Fee',
          icon: Icons.payments_outlined,
        ),
        DashboardQuickAction(
          id: 'homework',
          label: 'Homework',
          icon: Icons.assignment_outlined,
        ),
        DashboardQuickAction(
          id: 'timetable',
          label: 'Timetable',
          icon: Icons.calendar_view_week_outlined,
        ),
        DashboardQuickAction(
          id: 'exams',
          label: 'Exams',
          icon: Icons.grading_outlined,
        ),
        DashboardQuickAction(
          id: 'transport',
          label: 'Transport',
          icon: Icons.directions_bus_outlined,
        ),
        DashboardQuickAction(
          id: 'ptm',
          label: 'PTM',
          icon: Icons.groups_outlined,
        ),
        // PAR-2 — Apply Leave promoted onto the dashboard quick-actions grid
        // (previously reachable only via the "More" sheet).
        DashboardQuickAction(
          id: 'apply_leave',
          label: 'Apply Leave',
          icon: Icons.event_busy_outlined,
        ),
      ],
      todaySummary: [
        TodaySummaryItem(
          id: 'attendance',
          icon: Icons.fact_check_outlined,
          iconTone: DashboardChipTone.success,
          title: 'Present · Marked 9:12 AM',
        ),
        TodaySummaryItem(
          id: 'homework',
          icon: Icons.assignment_outlined,
          iconTone: DashboardChipTone.primary,
          title: '2 homework due today',
        ),
        TodaySummaryItem(
          id: 'timetable',
          icon: Icons.calendar_view_week_outlined,
          iconTone: DashboardChipTone.primary,
          title: 'Period 3 · Mathematics now',
        ),
        TodaySummaryItem(
          id: 'fees',
          icon: Icons.account_balance_wallet_outlined,
          iconTone: DashboardChipTone.warning,
          title: 'Term 2 installment due 12 Jun',
        ),
      ],
      notices: [
        DashboardNotice(
          id: 'n3',
          title: 'New bus route effective Monday',
          dateLabel: '1 Jun 2026',
        ),
        DashboardNotice(
          id: 'n1',
          title: 'PTM scheduled for 15 June — please confirm your slot',
          dateLabel: '5 Jun 2026',
          isUrgent: true,
        ),
        DashboardNotice(
          id: 'n2',
          title: 'Summer vacation dates announced',
          dateLabel: '3 Jun 2026',
        ),
      ],
      events: [
        DashboardEvent(
          id: 'e1',
          day: 12,
          month: 'Jun',
          title: 'Science Exhibition',
          subtitle: '9:00 AM · Main Hall',
        ),
        DashboardEvent(
          id: 'e2',
          day: 18,
          month: 'Jun',
          title: 'Parent-Teacher Meeting',
          subtitle: '2:00 PM · Block B',
        ),
        DashboardEvent(
          id: 'e3',
          day: 25,
          month: 'Jun',
          title: 'Annual Sports Day',
          subtitle: '8:00 AM · Sports Ground',
        ),
      ],
      aiInsight: DashboardAiInsight(
        message: 'Fee due in 5 days — pay early to avoid late fee',
        actionLabel: 'Pay now',
      ),
    );
  }

  /// Personalizes the dashboard greeting/identity for the active child.
  ///
  /// PAR-6: the per-child *data* (status, today summary, AI insight, notices,
  /// events) comes from the backend, which now receives `activeChildId` and
  /// returns that child's real dashboard. This only sets the identity/greeting;
  /// it no longer fabricates a hardcoded demo branch per child name.
  ParentDashboardData forActiveChild({
    required String childName,
    required String childClass,
  }) {
    final firstName = childName.trim().isEmpty
        ? ''
        : childName.trim().split(' ').first;
    return ParentDashboardData(
      childName: childName,
      childClass: childClass,
      greetingEyebrow: greetingEyebrow,
      greetingHeadline:
          firstName.isEmpty ? greetingHeadline : "$firstName's Day at a Glance",
      schoolName: schoolName,
      statusChips: statusChips,
      quickActions: quickActions,
      todaySummary: todaySummary,
      notices: notices,
      events: events,
      aiInsight: aiInsight,
      unreadNotifications: unreadNotifications,
    );
  }
}

enum DashboardChipTone { primary, success, warning, error }

@immutable
class DashboardStatusChip {
  const DashboardStatusChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final DashboardChipTone tone;
}

@immutable
class DashboardQuickAction {
  const DashboardQuickAction({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

@immutable
class TodaySummaryItem {
  const TodaySummaryItem({
    required this.id,
    required this.icon,
    required this.iconTone,
    required this.title,
  });

  final String id;
  final IconData icon;
  final DashboardChipTone iconTone;
  final String title;
}

@immutable
class DashboardNotice {
  const DashboardNotice({
    required this.id,
    required this.title,
    required this.dateLabel,
    this.isUrgent = false,
  });

  final String id;
  final String title;
  final String dateLabel;
  final bool isUrgent;
}

@immutable
class DashboardEvent {
  const DashboardEvent({
    required this.id,
    required this.day,
    required this.month,
    required this.title,
    this.subtitle,
  });

  final String id;
  final int day;
  final String month;
  final String title;
  final String? subtitle;
}

@immutable
class DashboardAiInsight {
  const DashboardAiInsight({
    required this.message,
    required this.actionLabel,
  });

  final String message;
  final String actionLabel;
}

final parentDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final parentDashboardErrorProvider = StateProvider<bool>((ref) => false);
final parentDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final parentDashboardFutureProvider = FutureProvider<ParentDashboardData>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  final base = await ref.read(parentRepositoryProvider).getDashboard(
        query: ref.watch(parentRepositoryQueryProvider),
      );
  if (child == null) return base;
  return base.forActiveChild(childName: child.name, childClass: child.classLabel);
});

final parentDashboardProvider = Provider<ParentDashboardData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(parentDashboardFutureProvider),
    manualLoading: ref.watch(parentDashboardLoadingProvider),
    manualError: ref.watch(parentDashboardErrorProvider),
    manualEmpty: ref.watch(parentDashboardEmptyProvider),
  );
  final raw = data ??
      ref.watch(parentDashboardFutureProvider).value ??
      ParentDashboardData.mock();
  return adaptParentDashboard(raw, ref.watch(schoolCapabilitiesProvider));
});
