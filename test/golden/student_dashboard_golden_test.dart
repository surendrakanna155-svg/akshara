@TestOn('mac-os')
library;

import 'package:akshara_erp/features/student/dashboard/student_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

void main() {
  group('Student Dashboard golden tests', () {
    for (final viewport in GoldenViewports.all) {
      testWidgets('renders at ${viewport.label}', (tester) async {
        await pumpGoldenDashboard(
          tester,
          screen: const StudentDashboardScreen(),
          viewport: viewport.size,
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(goldenFileName('student_dashboard', viewport.label)),
        );
      });
    }
  });
}
