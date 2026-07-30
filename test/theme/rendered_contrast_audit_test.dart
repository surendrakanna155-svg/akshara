import 'package:akshara_erp/shared/widgets/akshara_status_chip.dart';
import 'package:akshara_erp/theme/accessibility.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:akshara_erp/theme/typography.dart';
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

// A11y-P0 — tone foreground on tone container is NORMAL text, not large text.
//
// The previous revision of this file asserted only the 3.0:1 large-text floor
// with the comment "bold >= 14 -> large-text floor". That premise was wrong.
// `AksharaStatusChip` defaults to `AksharaStatusChipSize.compact`, which paints
// `labelSmall` (11px) at w600 — and WCAG 2.1 large text is >= 24px regular or
// >= 18.66px bold. 11px bold is normal text, so the floor is 4.5:1.
//
// Under the wrong 3.0 floor five pairs passed green while failing AA on the
// status chip used at 141 call sites ("Paid" / "Overdue" / "Absent" / "Late"):
//   light warning  #D97706 on #FFFBEB = 3.07:1
//   light tertiary #0D9488 on #CCFBF1 = 3.32:1
//   light error    #DC2626 on #FEF2F2 = 4.41:1
//   dark  tertiary #0D9488 on #0F3D38 = 3.21:1
//   dark  indigo   #818CF8 on #312E81 = 3.83:1
// All five were fixed by moving the FOREGROUND token (containers unchanged,
// hue unchanged) in lib/theme/color_tokens.dart. Do not lower this back to
// large-text unless the chip's default size stops being `compact`.
const double _minToneForegroundOnContainer =
    AksharaAccessibility.minContrastNormalText;

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

          // 1. AksharaStatusChip label — 11px `labelSmall` at w600, which is
          //    NORMAL text under WCAG 2.1, so 4.5:1 (see the note above).
          final toneRatio =
              AksharaAccessibility.contrastRatio(tone.foreground, tone.container);
          expect(
            toneRatio,
            greaterThanOrEqualTo(_minToneForegroundOnContainer),
            reason: '${entry.name}: $accent foreground on container is '
                '${toneRatio.toStringAsFixed(2)}:1 — below the WCAG AA '
                'normal-text floor of $_minToneForegroundOnContainer:1 that an '
                '11px AksharaStatusChip label requires.',
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

    // Guards the PREMISE of the 4.5:1 floor above. If the chip's default size
    // (or `labelSmall`'s size) ever changes, this fails and forces whoever
    // changed it to re-derive the floor rather than silently inheriting one.
    testWidgets('the chip default really is normal-size text', (tester) async {
      const wcagLargeBoldPt = 18.66; // WCAG 2.1: large = 14pt bold = 18.66px

      expect(
        const AksharaStatusChip(label: 'Paid', tone: KpiAccent.success).size,
        AksharaStatusChipSize.compact,
        reason: 'The 4.5:1 floor above is derived from the compact default.',
      );

      final context =
          await _themedContext(tester, AksharaAppTheme.light());
      final chipFontSize =
          Theme.of(context).extension<AksharaTextStyles>()!.labelSmall.fontSize!;

      expect(
        chipFontSize,
        lessThan(wcagLargeBoldPt),
        reason: 'A compact chip paints labelSmall (${chipFontSize}px). Below '
            '${wcagLargeBoldPt}px bold, WCAG 2.1 classes it as NORMAL text, so '
            'tone foreground on tone container must clear '
            '${AksharaAccessibility.minContrastNormalText}:1 — not the 3.0:1 '
            'large-text floor.',
      );
    });
  });
}
