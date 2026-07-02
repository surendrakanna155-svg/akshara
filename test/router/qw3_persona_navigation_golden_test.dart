import 'package:akshara_erp/router/parent_navigation.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/router/student_navigation.dart';
import 'package:akshara_erp/router/teacher_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// QW3 · QA-F-057 — Persona dashboard navigation builders (router golden map).
/// `parent_navigation.dart`, `teacher_navigation.dart`, `student_navigation.dart`
/// each map a dashboard `actionId` onto a GoRouter destination. This is a golden
/// route-map test: it drives EVERY action in each persona's table through a real
/// GoRouter and asserts it lands on the expected route. Iterating the table this
/// way guards against a mis-wired or dropped action mapping.

typedef _NavInvoker = void Function(BuildContext context, String actionId);

/// Builds a router that records every navigated location, fires [actionId]
/// through [invoke], and returns the location the builder routed to.
Future<String?> _navigate(
  WidgetTester tester, {
  required _NavInvoker invoke,
  required String actionId,
  required List<String> destinationPaths,
}) async {
  String? landed;
  final routes = <GoRoute>[
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => invoke(context, actionId),
            child: const Text('go'),
          ),
        ),
      ),
    ),
    for (final path in destinationPaths)
      GoRoute(
        path: path,
        builder: (context, state) {
          landed = state.uri.toString();
          return const SizedBox.shrink();
        },
      ),
  ];

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/', routes: routes),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return landed;
}

void main() {
  // ── Parent ────────────────────────────────────────────────────────────────
  // actionId → expected destination path. Only the ref-free, single-destination
  // mappings are covered here (child_switch / ai_copilot / experience_hub need a
  // WidgetRef and are exercised by the persona pilot tests).
  const parentMap = <String, String>{
    'academic_report': RouteNames.parentAcademicReport,
    'parent_insights': RouteNames.parentInsights,
    'fees': RouteNames.parentFees,
    'receipts': RouteNames.parentReceipts,
    'leave': RouteNames.parentLeave,
    'attendance': RouteNames.parentAttendance,
    'today_see_all': RouteNames.parentAttendance,
    'homework': RouteNames.parentHomework,
    'timetable': RouteNames.parentTimetable,
    'exams': RouteNames.parentExams,
    'report_card': RouteNames.parentExams,
    'transport': RouteNames.parentTransport,
    'ptm': RouteNames.parentPtm,
    'parent_teacher_meeting': RouteNames.parentPtm,
    'notices': RouteNames.parentNotices,
    'events': RouteNames.parentEvents,
    'profile': RouteNames.parentProfile,
    'contact_teacher': RouteNames.parentMessages,
    'notifications': RouteNames.parentNotifications,
    'pay_fee': RouteNames.parentPayment,
    // default-branch pattern matches.
    'notice_n1': RouteNames.parentPtm,
    'event_e2': RouteNames.parentPtm,
    'notice_n3': RouteNames.parentTransport,
    'notice_misc': RouteNames.parentNotices,
    'event_misc': RouteNames.parentEvents,
  };

  final parentDestinations = parentMap.values.toSet().toList();

  group('QA-F-057 · parent dashboard navigation map', () {
    for (final entry in parentMap.entries) {
      testWidgets('${entry.key} routes to ${entry.value}', (tester) async {
        final landed = await _navigate(
          tester,
          invoke: (context, id) =>
              handleParentDashboardNavigation(context, id),
          actionId: entry.key,
          destinationPaths: parentDestinations,
        );
        expect(landed, isNotNull,
            reason: '${entry.key} did not navigate anywhere');
        expect(landed!, startsWith(entry.value));
      });
    }
  });

  // ── Teacher ────────────────────────────────────────────────────────────────
  const teacherMap = <String, String>{
    'mark_attendance': RouteNames.teacherAttendance,
    // TCH-9 — the check-in card now opens the read-only My Attendance history.
    'my_attendance': RouteNames.teacherMyAttendance,
    'staff_check_in': RouteNames.teacherMyAttendance,
    'staff_check_in_now': RouteNames.teacherMyAttendance,
    'create_homework': RouteNames.teacherHomeworkCreate,
    'hw_review': RouteNames.teacherHomework,
    'homework': RouteNames.teacherHomework,
    'timetable': RouteNames.teacherTimetable,
    'exams': RouteNames.teacherExams,
    'messages': RouteNames.teacherMessages,
    'unread_messages': RouteNames.teacherMessages,
    'parent_communication': RouteNames.teacherParentCommunication,
    'leave': RouteNames.teacherLeave,
    'notifications': RouteNames.parentNotifications,
    'class_teacher_dashboard': RouteNames.teacherClassTeacherDashboard,
    'profile': RouteNames.teacherDashboard,
    'home': RouteNames.teacherDashboard,
    // default-branch pattern matches.
    'mark_attendance_p3': RouteNames.teacherAttendance,
    'class_5b': RouteNames.teacherTimetable,
  };

  final teacherDestinations = teacherMap.values.toSet().toList();

  group('QA-F-057 · teacher dashboard navigation map', () {
    for (final entry in teacherMap.entries) {
      testWidgets('${entry.key} routes to ${entry.value}', (tester) async {
        final landed = await _navigate(
          tester,
          invoke: (context, id) => handleTeacherNavigation(context, id),
          actionId: entry.key,
          destinationPaths: teacherDestinations,
        );
        expect(landed, isNotNull,
            reason: '${entry.key} did not navigate anywhere');
        expect(landed!, startsWith(entry.value));
      });
    }
  });

  // ── Student ────────────────────────────────────────────────────────────────
  const studentMap = <String, String>{
    'attendance': RouteNames.studentAttendance,
    'full_schedule': RouteNames.studentTimetable,
    'period_list': RouteNames.studentTimetable,
    'homework_list': RouteNames.studentHomework,
    'submit_homework': RouteNames.studentHomework,
    'homework': RouteNames.studentHomework,
    'exam_results': RouteNames.studentExams,
    'exams': RouteNames.studentExams,
    'report_card': RouteNames.studentReportCard,
    'progress': RouteNames.studentProgress,
    'academic_progress': RouteNames.studentProgress,
    'notices': RouteNames.studentNotices,
    'profile': RouteNames.studentProfile,
    'notifications': RouteNames.parentNotifications,
    'home': RouteNames.studentDashboard,
    // default-branch pattern matches.
    'homework_h2': RouteNames.studentHomework,
    'period_3': RouteNames.studentTimetable,
    'exam_e1': RouteNames.studentExams,
  };

  final studentDestinations = studentMap.values.toSet().toList();

  group('QA-F-057 · student dashboard navigation map', () {
    for (final entry in studentMap.entries) {
      testWidgets('${entry.key} routes to ${entry.value}', (tester) async {
        final landed = await _navigate(
          tester,
          invoke: (context, id) => handleStudentNavigation(context, id),
          actionId: entry.key,
          destinationPaths: studentDestinations,
        );
        expect(landed, isNotNull,
            reason: '${entry.key} did not navigate anywhere');
        expect(landed!, startsWith(entry.value));
      });
    }
  });
}
