import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'color_tokens.dart';
import 'stitch_palettes.dart';
import 'elevation.dart';
import 'locale_typography.dart';
import 'motion.dart';
import 'page_transitions.dart';
import 'premium_tokens.dart';
import 'radius.dart';
import 'spacing.dart';
import 'theme_extensions.dart';
import 'typography.dart';

/// Builds Material 3 [ThemeData] for the NIKSHA OS monorepo — M15 foundation.
///
/// Riverpod providers should call [AksharaAppTheme.light] / [.dark] with an
/// optional [WhiteLabelThemeConfig] — keep this class free of Riverpod imports.
abstract final class AksharaAppTheme {
  /// M15 premium light theme.
  static ThemeData light({
    WhiteLabelThemeConfig? whiteLabel,
    Locale? locale,
  }) {
    final tokens = AksharaColorTokens.light(
      primaryOverride: whiteLabel?.primary,
    );
    return _build(
      tokens: tokens,
      brightness: Brightness.light,
      locale: locale,
      accent: whiteLabel?.primary,
    );
  }

  /// M15 obsidian dark theme.
  static ThemeData dark({
    WhiteLabelThemeConfig? whiteLabel,
    Locale? locale,
  }) {
    final tokens = AksharaColorTokens.dark(
      primaryOverride: whiteLabel?.primary,
    );
    return _build(
      tokens: tokens,
      brightness: Brightness.dark,
      locale: locale,
      accent: whiteLabel?.primary,
    );
  }

  /// Stitch-aligned persona theme (M15.5) — colors from reference PNGs / DESIGN.md.
  static ThemeData stitch(
    StitchPersonaPalette palette, {
    WhiteLabelThemeConfig? whiteLabel,
    Locale? locale,
  }) {
    var tokens = AksharaStitchPalettes.tokens(palette);
    if (whiteLabel?.primary != null) {
      tokens = tokens.withPrimaryOverride(whiteLabel!.primary!);
    }
    return _build(
      tokens: tokens,
      brightness: AksharaStitchPalettes.brightness(palette),
      locale: locale,
    );
  }

  /// DS V2 — unified persona theme: shared M15 Light/Dark surfaces with the persona
  /// [accent] as primary. Honors the caller-resolved [brightness] (Appearance setting);
  /// personas no longer force a fixed brightness. White-label branding still wins.
  static ThemeData persona({
    required Brightness brightness,
    required Color accent,
    WhiteLabelThemeConfig? whiteLabel,
    Locale? locale,
  }) {
    final primary = whiteLabel?.primary ?? accent;
    final tokens = brightness == Brightness.dark
        ? AksharaColorTokens.dark(primaryOverride: primary)
        : AksharaColorTokens.light(primaryOverride: primary);
    return _build(
      tokens: tokens,
      brightness: brightness,
      locale: locale,
      accent: primary,
    );
  }

  static ThemeData _build({
    required AksharaColorTokens tokens,
    required Brightness brightness,
    Locale? locale,
    Color? accent,
  }) {
    final colorScheme = tokens.toColorScheme(brightness: brightness);
    final aksharaExtension = AksharaThemeExtension.fromTokens(
      tokens,
      brightness: brightness,
    );
    final aksharaText = AksharaLocaleTypography.applyLocale(
      AksharaTextStyles.roboto().applyColorScheme(colorScheme),
      locale,
    );
    final textTheme = aksharaText.toMaterialTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      disabledColor: colorScheme.onSurface.withValues(alpha: 0.38),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[
        aksharaExtension,
        aksharaText,
        _premiumTokens(brightness, accent),
      ],
      appBarTheme: _appBarTheme(colorScheme, aksharaText),
      navigationBarTheme: _navigationBarTheme(colorScheme, aksharaText),
      navigationRailTheme: _navigationRailTheme(colorScheme),
      navigationDrawerTheme: _navigationDrawerTheme(colorScheme),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        width: 280,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(colorScheme, aksharaText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _filledButtonStyle(colorScheme, aksharaText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(colorScheme, aksharaText),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _textButtonStyle(colorScheme, aksharaText),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: _iconButtonStyle(colorScheme),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: AksharaElevation.level3,
        focusElevation: AksharaElevation.level3,
        hoverElevation: AksharaElevation.level3,
        highlightElevation: AksharaElevation.level3,
        shape: RoundedRectangleBorder(borderRadius: AksharaRadius.fab),
        sizeConstraints: const BoxConstraints.tightFor(
          width: 56,
          height: 56,
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme, aksharaText),
      checkboxTheme: _checkboxTheme(colorScheme),
      chipTheme: _chipTheme(colorScheme, aksharaText),
      cardTheme: _cardTheme(colorScheme),
      dialogTheme: _dialogTheme(colorScheme, aksharaText),
      bottomSheetTheme: _bottomSheetTheme(colorScheme),
      snackBarTheme: _snackBarTheme(colorScheme, aksharaText),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.onPrimary,
        size: 24,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s4,
        ),
        minVerticalPadding: AksharaSpacing.s2,
        shape: RoundedRectangleBorder(borderRadius: AksharaRadius.chip),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          aksharaExtension.surfaceContainerHighest,
        ),
        headingTextStyle: aksharaText.tableHeader.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        dataTextStyle: aksharaText.tableCell,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        dividerThickness: 1,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: AksharaRadius.card,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        // DS V2 P2-3 — the un-themed M3 SegmentedButton was raw default Material
        // (pale secondaryContainer selected segment). Brand it like the rest of
        // the chrome: an accent-tinted selected segment (primary @ 14%) with a
        // full-strength accent label + checkmark, on a hairline outline.
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            aksharaText.labelLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.04);
            }
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary.withValues(alpha: 0.14);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.onSurfaceVariant;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.primary.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withValues(alpha: 0.06);
            }
            return null;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: aksharaText.labelLarge.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: aksharaText.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: colorScheme.primary, width: 3),
        ),
        dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.65),
        overlayColor: WidgetStatePropertyAll(
          colorScheme.primary.withValues(alpha: 0.06),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: aksharaText.bodySmall.copyWith(color: colorScheme.surface),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: AksharaRadius.chip,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AksharaElevation.level2,
        shape: RoundedRectangleBorder(borderRadius: AksharaRadius.chip),
        textStyle: aksharaText.bodyLarge,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: aksharaText.bodyLarge,
        inputDecorationTheme: _inputDecorationTheme(colorScheme, aksharaText),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          elevation: const WidgetStatePropertyAll(AksharaElevation.level3),
          shadowColor: WidgetStatePropertyAll(
            colorScheme.shadow.withValues(alpha: 0.12),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AksharaRadius.chipBorder),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 304)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          elevation: const WidgetStatePropertyAll(AksharaElevation.level2),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AksharaRadius.chipBorder),
          ),
        ),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: colorScheme.surface,
        contentTextStyle: aksharaText.bodyMedium,
        elevation: AksharaElevation.level1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outlineVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: AksharaFadePageTransitionsBuilder(),
          TargetPlatform.windows: AksharaFadePageTransitionsBuilder(),
        },
      ),
    );
  }

  /// The premium visual-system tokens for this theme. When an [accent] is known
  /// (a persona or white-label brand), the hero/AI/canvas surfaces are re-toned
  /// to it so they read cohesively with the branded chrome instead of the fixed
  /// indigo→violet brand (DS V2 P2-4).
  static AksharaPremiumTokens _premiumTokens(
    Brightness brightness,
    Color? accent,
  ) {
    final base = brightness == Brightness.dark
        ? AksharaPremiumTokens.dark()
        : AksharaPremiumTokens.light();
    return accent == null ? base : base.forAccent(accent);
  }

  static AppBarTheme _appBarTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return AppBarTheme(
      elevation: 0,
      // DS V2 P2-2 — flat at rest, but a soft shadow appears once content scrolls
      // beneath so the bar detaches cleanly from the page (premium structure).
      // No color change at rest; surfaceTint stays off.
      scrolledUnderElevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: 0.10),
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge.copyWith(color: scheme.onSurface),
      toolbarTextStyle: text.bodyLarge,
      systemOverlayStyle: scheme.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      toolbarHeight: AksharaSpacing.appBarHeightWeb,
    );
  }

  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return NavigationBarThemeData(
      height: AksharaSpacing.bottomNavHeight,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      // DS V2 P2-1 — branded persona chrome: a crisp accent-tinted stadium pill
      // (primary @ 16%) with a full-strength accent icon + label. Reads clearly
      // as the persona hue in BOTH light and dark (unlike the old washed M3
      // `primaryContainer` pill + dark `onPrimaryContainer` icon, which looked
      // near-identical across personas). Contrast holds: a 16% tint keeps the
      // pill pale enough that the full-strength `primary` icon clears 3:1.
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelMedium.copyWith(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          size: 24,
        );
      }),
    );
  }

  static NavigationRailThemeData _navigationRailTheme(ColorScheme scheme) {
    return NavigationRailThemeData(
      backgroundColor: scheme.surface,
      // DS V2 P2-1 — same branded accent pill as the bottom nav.
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }

  static NavigationDrawerThemeData _navigationDrawerTheme(ColorScheme scheme) {
    return NavigationDrawerThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      // DS V2 P2-1 — branded accent pill; selected row reads in the persona hue.
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? scheme.primary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
    );
  }

  static ButtonStyle _filledButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AksharaSpacing.s4, vertical: 14),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      animationDuration: AksharaMotion.fast,
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            scheme.onPrimary.withValues(alpha: 0.08),
            scheme.primary,
          );
        }
        return scheme.primary;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return 0;
        }
        if (states.contains(WidgetState.pressed)) {
          return AksharaElevation.level1;
        }
        if (states.contains(WidgetState.hovered)) {
          return AksharaElevation.level1;
        }
        return 0;
      }),
      shadowColor: WidgetStatePropertyAll(scheme.shadow),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.onPrimary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.onPrimary.withValues(alpha: 0.06);
        }
        return scheme.onPrimary.withValues(alpha: 0.04);
      }),
    );
  }

  static ButtonStyle _tonalButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AksharaSpacing.s4, vertical: 14),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      animationDuration: AksharaMotion.fast,
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimaryContainer),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            scheme.onPrimaryContainer.withValues(alpha: 0.06),
            scheme.primaryContainer,
          );
        }
        return scheme.primaryContainer;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return 0;
        }
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return AksharaElevation.level1;
        }
        return 0;
      }),
      shadowColor: WidgetStatePropertyAll(scheme.shadow),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.onPrimaryContainer.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.onPrimaryContainer.withValues(alpha: 0.06);
        }
        return scheme.onPrimaryContainer.withValues(alpha: 0.04);
      }),
    );
  }

  static ButtonStyle _outlinedButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AksharaSpacing.s3, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      animationDuration: AksharaMotion.fast,
      foregroundColor: WidgetStatePropertyAll(scheme.primary),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return scheme.primaryContainer.withValues(alpha: 0.35);
        }
        return scheme.surface;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return BorderSide(color: scheme.primary.withValues(alpha: 0.55));
        }
        return BorderSide(color: scheme.outlineVariant);
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AksharaElevation.level1;
        }
        return 0;
      }),
      shadowColor: WidgetStatePropertyAll(scheme.shadow),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: 0.05);
        }
        return Colors.transparent;
      }),
    );
  }

  static ButtonStyle _textButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AksharaSpacing.s3, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      animationDuration: AksharaMotion.fast,
      foregroundColor: WidgetStatePropertyAll(scheme.primary),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: 0.06);
        }
        return scheme.primary.withValues(alpha: 0.04);
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
    );
  }

  static ButtonStyle _iconButtonStyle(ColorScheme scheme) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      maximumSize: const WidgetStatePropertyAll(Size(48, 48)),
      iconSize: const WidgetStatePropertyAll(24),
      animationDuration: AksharaMotion.fast,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return scheme.primary;
        }
        return scheme.onSurfaceVariant;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: 0.06);
        }
        return scheme.onSurface.withValues(alpha: 0.04);
      }),
      shape: const WidgetStatePropertyAll(CircleBorder()),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: AksharaRadius.inputBorder,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s4,
      ),
      floatingLabelStyle: text.labelMedium.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      hintStyle: text.bodyLarge.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
      ),
      labelStyle: text.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: text.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: text.bodySmall.copyWith(color: scheme.error),
      border: border(scheme.outlineVariant.withValues(alpha: 0.75)),
      enabledBorder: border(scheme.outlineVariant.withValues(alpha: 0.75)),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error, 1.5),
      focusedErrorBorder: border(scheme.error, 2),
      disabledBorder: border(scheme.outlineVariant.withValues(alpha: 0.38)),
    );
  }

  static CheckboxThemeData _checkboxTheme(ColorScheme scheme) {
    return CheckboxThemeData(
      // UX-8: keep the full 48dp tap target (accessibility). The visual box is
      // still compact via `side`/`shape`; only the touch area is padded out.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      side: BorderSide(color: scheme.outlineVariant, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    );
  }

  static ChipThemeData _chipTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.onSurface.withValues(alpha: 0.12),
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s2,
        vertical: AksharaSpacing.s1,
      ),
      shape: RoundedRectangleBorder(borderRadius: AksharaRadius.chip),
      side: BorderSide(color: scheme.outlineVariant),
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 18,
      ),
    );
  }

  static CardThemeData _cardTheme(ColorScheme scheme) {
    return CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AksharaElevation.level0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  static DialogThemeData _dialogTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AksharaElevation.level4,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.dialog,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      titleTextStyle: text.titleLarge.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: text.bodyLarge.copyWith(color: scheme.onSurface),
      actionsPadding: const EdgeInsets.fromLTRB(AksharaSpacing.s6, AksharaSpacing.s0, AksharaSpacing.s6, AksharaSpacing.s6),
      insetPadding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s6, vertical: AksharaSpacing.s6),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) {
    return BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AksharaElevation.level4,
      modalElevation: AksharaElevation.level4,
      modalBackgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.bottomSheet,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      dragHandleSize: const Size(40, 4),
    );
  }

  static SnackBarThemeData _snackBarTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AksharaRadius.chip),
      elevation: AksharaElevation.level2,
    );
  }

  /// Tonal filled button style for secondary emphasis actions.
  static ButtonStyle tonalButtonStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).extension<AksharaTextStyles>()!;
    return _tonalButtonStyle(scheme, text);
  }
}
