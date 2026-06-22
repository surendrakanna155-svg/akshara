import 'package:akshara_erp/shared/forms/akshara_step_indicator.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = [
    'Student profile',
    'Parent information',
    'Academic information',
    'Review & submit',
  ];

  Widget harness({required int currentIndex}) {
    return MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: AksharaStepIndicator(
          stepLabels: labels,
          currentIndex: currentIndex,
        ),
      ),
    );
  }

  void useWidth(WidgetTester tester, double w) {
    tester.view.physicalSize = Size(w, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('AksharaStepIndicator', () {
    testWidgets('desktop renders every step label as the full row',
        (tester) async {
      useWidth(tester, 1200);
      await tester.pumpWidget(harness(currentIndex: 1));
      await tester.pumpAndSettle();

      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      // No compact "Step N of M" eyebrow on wide layouts.
      expect(find.textContaining('Step 2 of 4'), findsNothing);
      // Numbered circles are present (one CircleAvatar per step).
      expect(find.byType(CircleAvatar), findsNWidgets(labels.length));
    });

    testWidgets('phone collapses to a compact step + progress bar',
        (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(harness(currentIndex: 1));
      await tester.pumpAndSettle();

      // Compact form: eyebrow + current label + next hint + progress bar.
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Parent information'), findsOneWidget);
      expect(find.text('Next: Academic information'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // The full numbered-circle row is not used on phones.
      expect(find.byType(CircleAvatar), findsNothing);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.5, 0.0001)); // step 2 of 4
    });

    testWidgets('phone last step shows no "Next" hint and full progress',
        (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(harness(currentIndex: 3));
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.textContaining('Next:'), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(1.0, 0.0001));
    });
  });
}
