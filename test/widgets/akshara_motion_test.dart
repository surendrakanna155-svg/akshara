import 'package:akshara_erp/shared/widgets/akshara_motion.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaMotion', () {
    test('enterScale is subtle', () {
      expect(AksharaMotion.enterScale, greaterThan(0.95));
      expect(AksharaMotion.enterScale, lessThan(1));
    });

    testWidgets('AksharaMotionAppear renders child immediately in tests', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaMotionAppear(
              child: Text('Visible'),
            ),
          ),
        ),
      );

      expect(find.text('Visible'), findsOneWidget);
    });

    testWidgets('AksharaAnimatedSwitcher swaps content', (tester) async {
      var showA = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => showA = !showA),
                      child: const Text('toggle'),
                    ),
                    AksharaAnimatedSwitcher(
                      child: Text(
                        showA ? 'A' : 'B',
                        key: ValueKey(showA),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.text('toggle'));
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });
  });
}
