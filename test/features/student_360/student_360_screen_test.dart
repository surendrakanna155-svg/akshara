import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/student_360/student_360_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  testWidgets('Student360Screen shows tabbed dossier sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: providerTestOverrides(),
        child: const MaterialApp(
          home: Student360Screen(studentId: 'SIS-STU-10430'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.student360TabBar), findsOneWidget);
    expect(find.text('Arjun Reddy'), findsOneWidget);
    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Communication'), findsOneWidget);

    await tester.tap(find.text('Fees'));
    await tester.pumpAndSettle();
    expect(find.textContaining('₹5000'), findsOneWidget);
  });
}
