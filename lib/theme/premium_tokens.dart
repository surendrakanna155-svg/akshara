import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// "Premium School OS" visual-system tokens (approved 2026-06-20).
///
/// Additive layer over the M3 [ColorScheme] + [AksharaThemeExtension]. Holds the
/// premium brand gradient, soft tinted elevations, and the line-art illustration
/// language. Token-driven so the future **AI School Builder** can emit a
/// per-school theme by overriding [brandStart]/[brandEnd] (color) and the motif
/// pack — nothing here hardcodes a single school's identity.
///
/// Full spec: `docs/design/VISUAL_DESIGN_SYSTEM.md`.
@immutable
class AksharaPremiumTokens extends ThemeExtension<AksharaPremiumTokens> {
  const AksharaPremiumTokens({
    required this.brandStart,
    required this.brandEnd,
    required this.heroGradient,
    required this.aiBarGradient,
    required this.canvasGradient,
    required this.premiumSurface,
    required this.premiumBorder,
    required this.onHero,
    required this.onAiBar,
    required this.lineArtStroke,
    required this.lineArtOpacity,
    required this.heroMotifOpacity,
    required this.softShadow,
    required this.liftedShadow,
    required this.brightness,
  });

  /// Brand gradient endpoints (indigo → violet by default).
  final Color brandStart;
  final Color brandEnd;

  /// Greeting-hero card background gradient (soft tints in light, deep in dark).
  final List<Color> heroGradient;

  /// AI suggestion bar gradient (saturated brand).
  final List<Color> aiBarGradient;

  /// Full-screen soft canvas gradient behind dashboards.
  final List<Color> canvasGradient;

  /// Premium card fill + hairline border.
  final Color premiumSurface;
  final Color premiumBorder;

  /// Foreground (text/icon) colors on the hero / AI bar gradients.
  final Color onHero;
  final Color onAiBar;

  /// Line-art illustration stroke color + its decorative opacity range.
  final Color lineArtStroke;
  final double lineArtOpacity;

  /// Opacity for the larger motif tucked into the hero card.
  final double heroMotifOpacity;

  /// Soft, brand-tinted card elevation + a stronger lifted elevation.
  final List<BoxShadow> softShadow;
  final List<BoxShadow> liftedShadow;

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// The brand gradient as a [LinearGradient] (top-left → bottom-right).
  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandStart, brandEnd],
      );

  // ---- Factories ----------------------------------------------------------

  /// Premium **Light** — the default theme.
  factory AksharaPremiumTokens.light() {
    const start = Color(0xFF5B5BF0); // indigo
    const end = Color(0xFF8B5CF6); // violet
    return const AksharaPremiumTokens(
      brandStart: start,
      brandEnd: end,
      heroGradient: [
        Color(0xFFEEF0FF),
        Color(0xFFF1ECFE),
        Color(0xFFFBEFF6),
      ],
      aiBarGradient: [
        Color(0xFF6D5BF5),
        Color(0xFF7C5BE8),
        Color(0xFF9B5BD8),
      ],
      canvasGradient: [
        Color(0xFFF6F7FB),
        Color(0xFFF3F1FB),
        Color(0xFFFBF1F7),
      ],
      premiumSurface: Colors.white,
      premiumBorder: Color(0xFFECEAF6),
      onHero: Color(0xFF1E1B3A),
      onAiBar: Colors.white,
      lineArtStroke: start,
      lineArtOpacity: 0.10,
      heroMotifOpacity: 0.14,
      softShadow: [
        BoxShadow(
          color: Color(0x1A5B5BF0), // indigo @ ~10%
          blurRadius: 40,
          offset: Offset(0, 14),
        ),
        BoxShadow(
          color: Color(0x0A1E1B3A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
      liftedShadow: [
        BoxShadow(
          color: Color(0x335B5BF0), // indigo @ ~20%
          blurRadius: 60,
          offset: Offset(0, 24),
        ),
      ],
      brightness: Brightness.light,
    );
  }

  /// Dark Premium — the mode toggle (built now so dashboards work in both;
  /// surfaced to users in Phase C).
  factory AksharaPremiumTokens.dark() {
    const start = Color(0xFF8B8CFF);
    const end = Color(0xFF9B5BE6);
    return const AksharaPremiumTokens(
      brandStart: start,
      brandEnd: end,
      heroGradient: [
        Color(0xFF23244A),
        Color(0xFF1D1E3A),
        Color(0xFF241E3E),
      ],
      aiBarGradient: [
        Color(0xFF5B5CF2),
        Color(0xFF7048E0),
        Color(0xFF9A3FD4),
      ],
      canvasGradient: [
        Color(0xFF1B1C33),
        Color(0xFF12121F),
        Color(0xFF0A0A12),
      ],
      premiumSurface: Color(0xFF161726),
      premiumBorder: Color(0xFF282A44),
      onHero: Color(0xFFF5F4FF),
      onAiBar: Colors.white,
      lineArtStroke: Color(0xFF9FA0FF),
      lineArtOpacity: 0.14,
      heroMotifOpacity: 0.22,
      softShadow: [
        BoxShadow(
          color: Color(0x6B000000),
          blurRadius: 36,
          offset: Offset(0, 16),
        ),
      ],
      liftedShadow: [
        BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 50,
          offset: Offset(0, 22),
        ),
      ],
      brightness: Brightness.dark,
    );
  }

  // ---- ThemeExtension plumbing -------------------------------------------

  @override
  AksharaPremiumTokens copyWith({
    Color? brandStart,
    Color? brandEnd,
    List<Color>? heroGradient,
    List<Color>? aiBarGradient,
    List<Color>? canvasGradient,
    Color? premiumSurface,
    Color? premiumBorder,
    Color? onHero,
    Color? onAiBar,
    Color? lineArtStroke,
    double? lineArtOpacity,
    double? heroMotifOpacity,
    List<BoxShadow>? softShadow,
    List<BoxShadow>? liftedShadow,
    Brightness? brightness,
  }) {
    return AksharaPremiumTokens(
      brandStart: brandStart ?? this.brandStart,
      brandEnd: brandEnd ?? this.brandEnd,
      heroGradient: heroGradient ?? this.heroGradient,
      aiBarGradient: aiBarGradient ?? this.aiBarGradient,
      canvasGradient: canvasGradient ?? this.canvasGradient,
      premiumSurface: premiumSurface ?? this.premiumSurface,
      premiumBorder: premiumBorder ?? this.premiumBorder,
      onHero: onHero ?? this.onHero,
      onAiBar: onAiBar ?? this.onAiBar,
      lineArtStroke: lineArtStroke ?? this.lineArtStroke,
      lineArtOpacity: lineArtOpacity ?? this.lineArtOpacity,
      heroMotifOpacity: heroMotifOpacity ?? this.heroMotifOpacity,
      softShadow: softShadow ?? this.softShadow,
      liftedShadow: liftedShadow ?? this.liftedShadow,
      brightness: brightness ?? this.brightness,
    );
  }

  /// Overrides the brand color (and dependent gradients/strokes) — the hook the
  /// AI School Builder uses to theme a school from its brand color.
  AksharaPremiumTokens withBrand(Color start, Color end) {
    return copyWith(
      brandStart: start,
      brandEnd: end,
      lineArtStroke: isDark ? lineArtStroke : start,
      aiBarGradient: [start, Color.lerp(start, end, 0.5)!, end],
    );
  }

  /// DS V2 — re-tones every accent-dependent premium surface (hero gradient, AI
  /// bar, canvas, brand, line-art, colored card shadow) to a single persona
  /// [accent]. This is what makes a blue persona get a blue hero instead of the
  /// fixed indigo→violet brand. The neutral parts (premiumSurface, premiumBorder,
  /// onHero) stay mode-driven, so the hero stays a pale tint in light / deep tint
  /// in dark and the on-hero foreground keeps its contrast either way.
  AksharaPremiumTokens forAccent(Color accent) {
    final end = Color.lerp(accent, Colors.white, isDark ? 0.18 : 0.24)!;

    final List<Color> hero;
    final List<Color> canvas;
    if (isDark) {
      // Deep accent tints layered over the obsidian hero/canvas bases.
      hero = [
        Color.alphaBlend(accent.withValues(alpha: 0.22), heroGradient.first),
        Color.alphaBlend(accent.withValues(alpha: 0.12), heroGradient[1]),
        Color.alphaBlend(accent.withValues(alpha: 0.16), heroGradient.last),
      ];
      canvas = [
        for (final c in canvasGradient)
          Color.alphaBlend(accent.withValues(alpha: 0.05), c),
      ];
    } else {
      // Soft accent washes over white — stays pale so dark on-hero text holds.
      hero = [
        Color.alphaBlend(accent.withValues(alpha: 0.12), const Color(0xFFFFFFFF)),
        Color.alphaBlend(accent.withValues(alpha: 0.06), const Color(0xFFFFFFFF)),
        Color.alphaBlend(accent.withValues(alpha: 0.11), const Color(0xFFFFFFFF)),
      ];
      canvas = [
        for (final c in canvasGradient)
          Color.alphaBlend(accent.withValues(alpha: 0.04), c),
      ];
    }

    return copyWith(
      brandStart: accent,
      brandEnd: end,
      heroGradient: hero,
      canvasGradient: canvas,
      aiBarGradient: [accent, Color.lerp(accent, end, 0.5)!, end],
      lineArtStroke: isDark ? lineArtStroke : accent,
      // Light: a soft accent-tinted glow under the hero card (cohesive colored
      // shadow). Dark: keep the neutral near-black drop.
      softShadow: isDark
          ? softShadow
          : [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 40,
                offset: const Offset(0, 14),
              ),
              const BoxShadow(
                color: Color(0x0A1E1B3A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
      liftedShadow: isDark
          ? liftedShadow
          : [
              BoxShadow(
                color: accent.withValues(alpha: 0.20),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
            ],
    );
  }

  @override
  AksharaPremiumTokens lerp(
    covariant ThemeExtension<AksharaPremiumTokens>? other,
    double t,
  ) {
    if (other is! AksharaPremiumTokens) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) {
      final n = a.length < b.length ? a.length : b.length;
      return [for (var i = 0; i < n; i++) Color.lerp(a[i], b[i], t)!];
    }

    return AksharaPremiumTokens(
      brandStart: Color.lerp(brandStart, other.brandStart, t)!,
      brandEnd: Color.lerp(brandEnd, other.brandEnd, t)!,
      heroGradient: lerpList(heroGradient, other.heroGradient),
      aiBarGradient: lerpList(aiBarGradient, other.aiBarGradient),
      canvasGradient: lerpList(canvasGradient, other.canvasGradient),
      premiumSurface: Color.lerp(premiumSurface, other.premiumSurface, t)!,
      premiumBorder: Color.lerp(premiumBorder, other.premiumBorder, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      onAiBar: Color.lerp(onAiBar, other.onAiBar, t)!,
      lineArtStroke: Color.lerp(lineArtStroke, other.lineArtStroke, t)!,
      lineArtOpacity:
          lerpDouble(lineArtOpacity, other.lineArtOpacity, t) ?? lineArtOpacity,
      heroMotifOpacity:
          lerpDouble(heroMotifOpacity, other.heroMotifOpacity, t) ??
              heroMotifOpacity,
      softShadow: t < 0.5 ? softShadow : other.softShadow,
      liftedShadow: t < 0.5 ? liftedShadow : other.liftedShadow,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// Theme accessor for the premium tokens.
extension AksharaPremiumContext on BuildContext {
  AksharaPremiumTokens get premium =>
      Theme.of(this).extension<AksharaPremiumTokens>()!;

  AksharaPremiumTokens? get premiumOrNull =>
      Theme.of(this).extension<AksharaPremiumTokens>();
}
