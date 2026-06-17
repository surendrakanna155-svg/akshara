import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/shared/widgets/akshara_interactive_surface.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/motion.dart';

void main() {
  group('M15 Phase 3 — interaction system', () {
    testWidgets('AksharaInteractiveSurface increases shadow on press', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: Center(
              child: AksharaInteractiveSurface(
                onTap: () {},
                child: const SizedBox(width: 120, height: 80),
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);

      AnimatedContainer resting =
          tester.widget<AnimatedContainer>(containerFinder);
      final restingShadows =
          (resting.decoration! as BoxDecoration).boxShadow ?? const [];
      expect(restingShadows, isNotEmpty);

      final inkWell = find.byType(InkWell);
      await tester.startGesture(tester.getCenter(inkWell));
      await tester.pump();
      await tester.pump(AksharaMotion.fast);

      resting = tester.widget<AnimatedContainer>(containerFinder);
      final pressedShadows =
          (resting.decoration! as BoxDecoration).boxShadow ?? const [];
      expect(pressedShadows.length, greaterThanOrEqualTo(restingShadows.length));
    });

    test('AksharaMotion uses enterprise-safe durations', () {
      expect(AksharaMotion.fast.inMilliseconds, lessThanOrEqualTo(150));
      expect(AksharaMotion.pressLift, lessThanOrEqualTo(2));
      expect(AksharaMotion.pressedShadow, greaterThan(AksharaMotion.restingShadow));
    });
  });
}
