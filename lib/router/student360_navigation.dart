import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'phase4_navigation.dart';

/// Navigates to the unified [Student360Screen] for the given SIS student id.
void openStudent360(BuildContext context, String studentId) {
  if (studentId.trim().isEmpty) return;
  context.push(student360Path(studentId));
}
