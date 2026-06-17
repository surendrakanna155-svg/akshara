import 'package:akshara_erp/shared/widgets/akshara_glass_surface.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaGlassSurface', () {
    testWidgets('renders child inside glass card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaGlassCard(
              child: Text('Hero content'),
            ),
          ),
        ),
      );

      expect(find.text('Hero content'), findsOneWidget);
    });

    testWidgets('hero backdrop wraps glass card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaGlassHeroBackdrop(
              child: AksharaGlassCard(
                child: Text('Dashboard hero'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dashboard hero'), findsOneWidget);
      expect(find.byType(AksharaGlassHeroBackdrop), findsOneWidget);
    });
  });

  group('AksharaGlass tokens', () {
    test('blur sigma defaults are defined', () {
      expect(AksharaGlass.blurSigma, greaterThan(0));
      expect(AksharaGlass.blurSigmaLight, lessThan(AksharaGlass.blurSigma));
    });
  });
}
