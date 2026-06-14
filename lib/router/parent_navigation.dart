import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/staging_probe_ids.dart';
import '../features/copilot/copilot_navigation.dart';
import 'route_names.dart';
import '../features/parent/parent_active_child_provider.dart';
import '../features/parent/widgets/parent_child_switcher_sheet.dart';

/// Maps PA-01 dashboard [actionId] values to GoRouter destinations.
void handleParentDashboardNavigation(
  BuildContext context,
  String actionId, {
  WidgetRef? ref,
}) {
  switch (actionId) {
    case 'experience_hub':
      final studentId = ref != null
          ? ref.read(parentActiveStudentIdProvider)
          : StagingProbeIds.studentAId;
      context.push(parentExperienceHubPath(studentId));
    case 'academic_report':
      context.push(RouteNames.parentAcademicReport);
    case 'child_switch':
      if (ref != null) {
        showParentChildSwitcherSheet(context, ref);
      }
    case 'pay_fee':
      context.push(
        '${RouteNames.parentPayment}?installmentId=term_2',
      );
    case 'fees':
      context.go(RouteNames.parentFees);
    case 'receipts':
      context.go(RouteNames.parentReceipts);
    case 'leave':
      context.go(RouteNames.parentLeave);
    case 'attendance':
    case 'today_see_all':
      context.go(RouteNames.parentAttendance);
    case 'homework':
      context.go(RouteNames.parentHomework);
    case 'timetable':
      context.go(RouteNames.parentTimetable);
    case 'exams':
    case 'report_card':
      context.go(RouteNames.parentExams);
    case 'notices':
      context.go(RouteNames.parentNotices);
    case 'events':
      context.go(RouteNames.parentEvents);
    case 'profile':
      context.go(RouteNames.parentProfile);
    case 'contact_teacher':
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    case 'ai_copilot':
      if (ref != null) {
        openAiPersonaAssistant(context, ref);
      } else {
        context.push(RouteNames.aiAssistant);
      }
    default:
      if (actionId.startsWith('notice_')) {
        context.go(RouteNames.parentNotices);
      } else if (actionId.startsWith('event_')) {
        context.go(RouteNames.parentEvents);
      }
      break;
  }
}

/// Fees-area navigation helpers (PA-03, PA-10, PA-11).
void handleParentFeesNavigation(
  BuildContext context, {
  String? installmentId,
  String? receiptId,
  bool openReceipts = false,
  bool openPayment = false,
}) {
  if (openReceipts) {
    context.go(RouteNames.parentReceipts);
    return;
  }
  if (receiptId != null) {
    context.push(RouteNames.parentReceiptDetail(receiptId));
    return;
  }
  if (openPayment || installmentId != null) {
    final id = installmentId ?? 'term_2';
    context.push('${RouteNames.parentPayment}?installmentId=$id');
    return;
  }
}

/// Academics-area navigation helpers (PA-04–PA-06).
void handleParentAcademicsNavigation(BuildContext context, String destination) {
  switch (destination) {
    case 'timetable':
      context.go(RouteNames.parentTimetable);
    case 'homework':
      context.go(RouteNames.parentHomework);
    case 'exams':
      context.go(RouteNames.parentExams);
    case 'attendance':
      context.go(RouteNames.parentAttendance);
    default:
      break;
  }
}
