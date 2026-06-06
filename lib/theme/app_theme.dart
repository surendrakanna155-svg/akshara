import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'color_tokens.dart';
import 'elevation.dart';
import 'radius.dart';
import 'spacing.dart';
import 'theme_extensions.dart';
import 'typography.dart';

/// Builds Material 3 [ThemeData] for the Akshara ERP monorepo.
///
/// Riverpod providers should call [AksharaAppTheme.light] / [.dark] with an
/// optional [WhiteLabelThemeConfig] — keep this class free of Riverpod imports.
abstract final class AksharaAppTheme {
  /// Default light theme (ship first).
  static ThemeData light({WhiteLabelThemeConfig? whiteLabel}) {
    final tokens = AksharaColorTokens.light(
      primaryOverride: whiteLabel?.primary,
    );
    return _build(
      tokens: tokens,
      brightness: Brightness.light,
    );
  }

  /// Dark theme placeholder (P2).
  static ThemeData dark({WhiteLabelThemeConfig? whiteLabel}) {
    final tokens = AksharaColorTokens.dark(
      primaryOverride: whiteLabel?.primary,
    );
    return _build(
      tokens: tokens,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _build({
    required AksharaColorTokens tokens,
    required Brightness brightness,
  }) {
    final colorScheme = tokens.toColorScheme(brightness: brightness);
    final aksharaExtension = AksharaThemeExtension.fromTokens(tokens);
    final aksharaText =
        AksharaTextStyles.roboto().applyColorScheme(colorScheme);
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
        headingTextStyle: aksharaText.labelSmall.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        dataTextStyle: aksharaText.bodyLarge,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        dividerThickness: 1,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: AksharaRadius.card,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: aksharaText.labelLarge,
        unselectedLabelStyle: aksharaText.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        dividerColor: colorScheme.outlineVariant,
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
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          elevation: const WidgetStatePropertyAll(AksharaElevation.level2),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AksharaRadius.chipBorder),
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
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static AppBarTheme _appBarTheme(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
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
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelMedium.copyWith(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          size: 24,
        );
      }),
    );
  }

  static NavigationRailThemeData _navigationRailTheme(ColorScheme scheme) {
    return NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w500,
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
      indicatorColor: scheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
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
        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        return scheme.primary;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStatePropertyAll(
        scheme.onPrimary.withValues(alpha: 0.08),
      ),
    );
  }

  static ButtonStyle _tonalButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimaryContainer),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        return scheme.primaryContainer;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );
  }

  static ButtonStyle _outlinedButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      foregroundColor: WidgetStatePropertyAll(scheme.primary),
      backgroundColor: WidgetStatePropertyAll(scheme.surface),
      side: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.disabled)
            ? scheme.outlineVariant.withValues(alpha: 0.38)
            : scheme.outlineVariant;
        return BorderSide(color: color);
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AksharaRadius.button),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );
  }

  static ButtonStyle _textButtonStyle(
    ColorScheme scheme,
    AksharaTextStyles text,
  ) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      foregroundColor: WidgetStatePropertyAll(scheme.primary),
      overlayColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: 0.08),
      ),
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
      foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
      overlayColor: WidgetStatePropertyAll(
        scheme.onSurface.withValues(alpha: 0.08),
      ),
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
      fillColor: scheme.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s4,
      ),
      hintStyle: text.bodyLarge.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: text.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: text.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: text.bodySmall.copyWith(color: scheme.error),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error, 2),
      focusedErrorBorder: border(scheme.error, 2),
      disabledBorder: border(scheme.outlineVariant.withValues(alpha: 0.38)),
    );
  }

  static CheckboxThemeData _checkboxTheme(ColorScheme scheme) {
    return CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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
      elevation: AksharaElevation.level1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: scheme.outlineVariant),
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
      elevation: AksharaElevation.level3,
      shape: RoundedRectangleBorder(borderRadius: AksharaRadius.dialog),
      titleTextStyle: text.titleLarge.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyLarge.copyWith(color: scheme.onSurface),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) {
    return BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AksharaElevation.level4,
      modalElevation: AksharaElevation.level4,
      shape: RoundedRectangleBorder(borderRadius: AksharaRadius.bottomSheet),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      dragHandleSize: const Size(36, 4),
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
