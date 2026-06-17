import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/shared/widgets/akshara_motion.dart';
import 'package:akshara_erp/shared/widgets/akshara_dialog.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_kpi_card.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/locale_typography.dart';
import 'package:akshara_erp/theme/m15_design_system.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/stress_fixtures.dart';
import '../test_helpers.dart';

Widget _scaledApp({
  required Widget home,
  required ThemeData theme,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  group('M15 Phase 12 — contrast', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('critical ColorScheme pairs meet WCAG AA ($brightness)', () {
        final scheme = brightness == Brightness.light
            ? AksharaAppTheme.light().colorScheme
            : AksharaAppTheme.dark().colorScheme;

        for (final pair in AksharaAccessibility.criticalSchemePairs(scheme)) {
          final ratio = AksharaAccessibility.contrastRatio(
            pair.foreground,
            pair.background,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(pair.minRatio),
            reason:
                '${pair.name} ratio ${ratio.toStringAsFixed(2)}:1 '
                'below ${pair.minRatio}:1 ($brightness)',
          );
        }
      });
    }

    test('semantic tokens contrast on their containers', () {
      final tokens = AksharaColorTokens.light();

      expect(
        AksharaAccessibility.meetsNormalTextContrast(
          tokens.success,
          tokens.successContainer,
        ),
        isTrue,
        reason: 'success on successContainer',
      );
      expect(
        AksharaAccessibility.meetsLargeTextContrast(
          tokens.warning,
          tokens.warningContainer,
        ),
        isTrue,
        reason: 'warning on warningContainer (chip/banner labels)',
      );
      expect(
        AksharaAccessibility.meetsLargeTextContrast(
          tokens.error,
          tokens.errorContainer,
        ),
        isTrue,
        reason: 'error on errorContainer (banner/chip labels)',
      );
    });
  });

  group('M15 Phase 12 — typography readability', () {
    test('label styles stay above minimum legible size', () {
      final text = AksharaAppTheme.light().extension<AksharaTextStyles>()!;

      expect(text.labelSmall.fontSize, greaterThanOrEqualTo(
        AksharaAccessibility.minLabelFontSize,
      ));
      expect(text.bodySmall.fontSize, greaterThanOrEqualTo(12));
      expect(text.bodyMedium.fontSize, greaterThanOrEqualTo(14));
    });

    test('KPI value scale preserves hierarchy at large sizes', () {
      final text = AksharaAppTheme.light().extension<AksharaTextStyles>()!;

      expect(text.kpiValue.fontSize, greaterThan(text.kpiLabel.fontSize!));
      expect(text.displayLarge.fontSize, greaterThan(text.titleLarge.fontSize!));
    });
  });

  group('M15 Phase 12 — locale typography', () {
    test('all supported language codes map to script fonts', () {
      for (final code in AksharaLocaleTypography.supportedLanguageCodes) {
        if (code == 'en') {
          expect(
            AksharaLocaleTypography.scriptFontFamilyFor(Locale(code)),
            isNull,
          );
          continue;
        }

        expect(
          AksharaLocaleTypography.scriptFontFamilyFor(Locale(code)),
          isNotNull,
          reason: code,
        );
      }
    });

    test('regional locales apply Noto families in theme', () {
      final teTheme = AksharaAppTheme.light(locale: const Locale('te'));
      final teText = teTheme.extension<AksharaTextStyles>()!;

      expect(teText.bodyMedium.fontFamily, AksharaLocaleTypography.telugu);
      expect(
        teText.bodyMedium.fontFamilyFallback,
        contains(AksharaTextStyles.robotoFamily),
      );
    });

    test('Urdu locale is flagged RTL', () {
      expect(AksharaLocaleTypography.isRtlLocale(const Locale('ur')), isTrue);
      expect(AksharaLocaleTypography.isRtlLocale(const Locale('en')), isFalse);
    });
  });

  group('M15 Phase 12 — shared widgets at large text scale', () {
    const maxScale = 2.0;
    const narrowWidth = 360.0;

    Future<void> pumpScaled(
      WidgetTester tester, {
      required Widget child,
      ThemeData? theme,
      bool settle = true,
    }) async {
      tester.view.physicalSize = const Size(narrowWidth, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _scaledApp(
          theme: theme ?? AksharaAppTheme.light(),
          textScale: maxScale,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    testWidgets('AksharaEmptyState at 2.0x', (tester) async {
      await pumpScaled(
        tester,
        child: const AksharaEmptyState(
          message: 'No homework assigned for this week.',
          actionLabel: 'Refresh',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('No homework assigned for this week.'), findsOneWidget);
    });

    testWidgets('AksharaErrorState at 2.0x', (tester) async {
      await pumpScaled(
        tester,
        child: AksharaErrorState(
          message: 'Network unavailable',
          onRetry: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('AksharaLoadingState at 2.0x', (tester) async {
      await pumpScaled(
        tester,
        settle: false,
        child: const AksharaLoadingState(
          semanticLabel: 'Loading attendance',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AksharaKpiCard at 2.0x', (tester) async {
      await pumpScaled(
        tester,
        child: const SizedBox(
          width: narrowWidth - 32,
          height: 280,
          child: AksharaKpiCard(
            style: AksharaKpiCardStyle.filled,
            value: '94%',
            subtitle: 'Attendance',
            accent: KpiAccent.primary,
            detail: '+2% vs last week',
            icon: Icons.school_outlined,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AksharaAlertDialog at 2.0x dark theme', (tester) async {
      await pumpScaled(
        tester,
        theme: AksharaAppTheme.dark(),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showAksharaDialog<void>(
                  context: context,
                  builder: (context) => const AksharaAlertDialog(
                    title: 'Confirm action',
                    content: Text('Save changes before leaving?'),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm action'), findsOneWidget);
    });
  });

  group('M15 Phase 12 — dark theme dashboard stress', () {
    testWidgets('Parent dashboard dark mode at 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentDashboardProvider.overrideWith(
              (ref) => StressFixtures.stressParentDashboard(),
            ),
          ]),
          child: _scaledApp(
            theme: AksharaAppTheme.dark(),
            textScale: 2.0,
            home: const ParentDashboardScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Good morning'), findsWidgets);
    });
  });
}
