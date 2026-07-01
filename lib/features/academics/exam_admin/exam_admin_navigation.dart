import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import 'exam_administration_screen.dart';
import 'exam_marks_entry_screen.dart';
import 'exam_reports_screen.dart';

Widget examAdministrationRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ExamAdministrationScreen();
}

/// EXM-3/4/5/7 — Exam Reports area route.
Widget examReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ExamReportsScreen();
}

void openExamReports(BuildContext context) {
  context.push(RouteNames.examReports);
}

Widget examMarksEntryRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final examId = state.pathParameters['examId'] ?? '';
  return ExamMarksEntryScreen(examId: examId);
}

void openExamMarksEntry(BuildContext context, String examId) {
  if (examId.trim().isEmpty) return;
  context.push(RouteNames.examAdministrationMarksPath(examId));
}
