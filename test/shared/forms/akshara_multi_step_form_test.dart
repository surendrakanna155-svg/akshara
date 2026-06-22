import 'package:akshara_erp/shared/forms/akshara_multi_step_form.dart';
import 'package:akshara_erp/shared/forms/akshara_step_indicator.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = ['One', 'Two', 'Three'];

  Widget harness({
    required int currentIndex,
    Widget? leading,
    Widget trailing = const Text('Continue'),
    GlobalKey<FormState>? formKey,
  }) {
    return MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: AksharaMultiStepForm(
          stepLabels: labels,
          currentIndex: currentIndex,
          formKey: formKey,
          leading: leading,
          trailing: trailing,
          child: const Text('step body'),
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

  group('AksharaMultiStepForm', () {
    testWidgets('renders the indicator, content and trailing action',
        (tester) async {
      useWidth(tester, 1200);
      await tester.pumpWidget(harness(currentIndex: 0));
      await tester.pumpAndSettle();

      expect(find.byType(AksharaStepIndicator), findsOneWidget);
      expect(find.text('step body'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('omits leading when null, shows it when provided',
        (tester) async {
      useWidth(tester, 1200);
      await tester.pumpWidget(harness(currentIndex: 0));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsNothing);

      await tester.pumpWidget(
        harness(currentIndex: 1, leading: const Text('Back')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('wraps content in a Form when a formKey is given',
        (tester) async {
      useWidth(tester, 1200);
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(harness(currentIndex: 0, formKey: key));
      await tester.pumpAndSettle();

      expect(find.byType(Form), findsOneWidget);
      expect(key.currentState, isNotNull);
    });

    testWidgets('no Form when formKey omitted', (tester) async {
      useWidth(tester, 1200);
      await tester.pumpWidget(harness(currentIndex: 0));
      await tester.pumpAndSettle();
      expect(find.byType(Form), findsNothing);
    });
  });
}
