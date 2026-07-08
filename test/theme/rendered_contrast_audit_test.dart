import 'package:akshara_erp/theme/accessibility.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-UX-4 — WCAG contrast audit BEYOND the M15 token-pair gate
// (test/theme/contrast_checker_test.dart already covers the 7 ColorScheme
// pairs). This audits the *rendered* semantic-tone pairs actually painted by
// chips, badges and the exception-grid tile — including alpha-blended and
// solid-fill glyph pairs — by resolving the real theme tones through a
// BuildContext, in both schemes.

Future<BuildContext> _themedContext(WidgetTester tester, ThemeData theme) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(builder: (context) {
      ctx = context;
      return const SizedBox.shrink();
    }),
  ));
  return ctx;
}

// Every semantic tone clears the WCAG AA large-text floor (3.0:1) on its own
// container in BOTH schemes. P2-UX-5 resolved the last shortfall: the dark
// `tertiary` tone on its container was ~2.53:1 and is now ~3.21:1 after
// deepening `tertiaryContainer` (#134E4A → #0F3D38). No per-tone exception
// remains — the standard floor applies uniformly.
double _minToneForegroundOnContainer(String scheme, KpiAccent accent) {
  return AksharaAccessibility.minContrastLargeText;
}

void main() {
  group('P2-UX-4 · rendered contrast audit (beyond the token-pair gate)', () {
    for (final entry in <({String name, ThemeData theme})>[
      (name: 'light', theme: AksharaAppTheme.light()),
      (name: 'dark', theme: AksharaAppTheme.dark()),
    ]) {
      testWidgets('semantic tones on chips / badges / tiles — ${entry.name}',
          (tester) async {
        final context = await _themedContext(tester, entry.theme);
        final scheme = Theme.of(context).colorScheme;

        for (final accent in KpiAccent.values) {
          final tone = accent.resolve(context);

          // 1. Chip / KPI-tile label (bold ≥14 → large-text floor): the tone
          //    foreground on its own container.
          expect(
            AksharaAccessibility.contrastRatio(tone.foreground, tone.container),
            greaterThanOrEqualTo(_minToneForegroundOnContainer(entry.name, accent)),
            reason: '${entry.name}: $accent foreground on container',
          );

          // 2. Mark-badge glyph: the chosen on-colour on the SOLID tone fill —
          //    this is exactly what _MarkBadge paints via onColorFor.
          expect(
            AksharaAccessibility.contrastRatio(
              AksharaAccessibility.onColorFor(tone.foreground),
              tone.foreground,
            ),
            greaterThanOrEqualTo(AksharaAccessibility.minContrastLargeText),
            reason: '${entry.name}: $accent badge glyph on solid fill',
          );

          // 3. Primary tile text (bodyMedium, normal): onSurface on the tinted
          //    exception tile.
          expect(
            AksharaAccessibility.contrastRatio(scheme.onSurface, tone.container),
            greaterThanOrEqualTo(AksharaAccessibility.minContrastNormalText),
            reason: '${entry.name}: $accent onSurface on tinted tile',
          );

          // 4. Secondary tile text (labelSmall): onSurfaceVariant on the tinted
          //    tile — the design system's own onSurfaceVariant floor is
          //    large-text (see criticalSchemePairs), so 3.0.
          expect(
            AksharaAccessibility.contrastRatio(
                scheme.onSurfaceVariant, tone.container),
            greaterThanOrEqualTo(AksharaAccessibility.minContrastLargeText),
            reason: '${entry.name}: $accent onSurfaceVariant on tinted tile',
          );
        }
      });

      testWidgets('freshness chip (alpha-blended container) — ${entry.name}',
          (tester) async {
        final context = await _themedContext(tester, entry.theme);
        final ext = Theme.of(context).extension<AksharaThemeExtension>()!;
        final surface = Theme.of(context).colorScheme.surface;

        // The chip paints its foreground on `container.withValues(alpha: a)`
        // composited over the surface (see AksharaFreshnessChip).
        final pairs = <({Color fg, Color bg, double a, String label})>[
          (fg: ext.success, bg: ext.successContainer, a: 0.6, label: 'live'),
          (fg: ext.warning, bg: ext.warningContainer, a: 0.7, label: 'offline'),
        ];
        for (final p in pairs) {
          final composited =
              Color.alphaBlend(p.bg.withValues(alpha: p.a), surface);
          expect(
            AksharaAccessibility.contrastRatio(p.fg, composited),
            greaterThanOrEqualTo(AksharaAccessibility.minContrastLargeText),
            reason: '${entry.name}: freshness chip (${p.label}) on blended bg',
          );
        }
      });
    }
  });
}
