import 'package:akshara_erp/shared/widgets/akshara_quick_action_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-UX-4 (Polish §7): "48dp targets already enforced in theme — add a lint."
// The theme-level assertions are the lint (they hold the 48dp line); the
// rendered guideline checks prove the shared content controls actually meet the
// Android tap-target guideline.

void main() {
  final theme = AksharaAppTheme.light();

  group('P2-UX-4 · tap-target lint (theme enforces ≥48dp)', () {
    test('minimum touch-target spacing token is 48', () {
      expect(AksharaSpacing.minTouchTarget, 48);
    });

    test('IconButton theme clamps to a 48×48 target', () {
      final size = theme.iconButtonTheme.style?.minimumSize?.resolve({});
      expect(size, isNotNull);
      expect(size!.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    test('Checkbox uses a padded (48dp) tap target', () {
      expect(
        theme.checkboxTheme.materialTapTargetSize,
        MaterialTapTargetSize.padded,
      );
    });

    test('root materialTapTargetSize is padded (no global shrinkWrap)', () {
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    test('primary filled button is ≥48dp tall', () {
      final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(size, isNotNull);
      expect(size!.height, greaterThanOrEqualTo(48));
    });
  });

  group('P2-UX-4 · shared content controls meet the Android 48dp guideline', () {
    testWidgets('quick-action card + filled button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160,
                  child: AksharaQuickActionCard(
                    icon: Icons.check_circle_outline,
                    label: 'Mark attendance',
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () {}, child: const Text('Save')),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
