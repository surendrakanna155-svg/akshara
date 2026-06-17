import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Stitch reference design systems — sourced from
/// `stitch_akshara_premium_enterprise_erp/*/DESIGN.md` and screen PNGs.
enum StitchPersonaPalette {
  obsidianEnterprise,
  aksharaParent,
  studentPulse,
  classroomCommand,
}

Color _hex(String value) {
  final normalized = value.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

/// Builds [AksharaColorTokens] aligned to Stitch persona palettes (M15.5).
abstract final class AksharaStitchPalettes {
  static AksharaColorTokens tokens(StitchPersonaPalette palette) {
    return switch (palette) {
      StitchPersonaPalette.obsidianEnterprise => _obsidianEnterprise(),
      StitchPersonaPalette.aksharaParent => _aksharaParent(),
      StitchPersonaPalette.studentPulse => _studentPulse(),
      StitchPersonaPalette.classroomCommand => _classroomCommand(),
    };
  }

  static Brightness brightness(StitchPersonaPalette palette) {
    return switch (palette) {
      StitchPersonaPalette.aksharaParent => Brightness.light,
      _ => Brightness.dark,
    };
  }

  /// Obsidian Enterprise — ERP executive / principal command center.
  static AksharaColorTokens _obsidianEnterprise() {
    return AksharaColorTokens(
      primary: _hex('#6366F1'),
      onPrimary: _hex('#FFFFFF'),
      primaryContainer: _hex('#312E81'),
      onPrimaryContainer: _hex('#E0E7FF'),
      secondary: _hex('#C0C1FF'),
      onSecondary: _hex('#1000A9'),
      secondaryContainer: _hex('#3131C0'),
      onSecondaryContainer: _hex('#B0B2FF'),
      tertiary: _hex('#DDB7FF'),
      onTertiary: _hex('#490080'),
      tertiaryContainer: _hex('#1B0035'),
      onTertiaryContainer: _hex('#A450F2'),
      surface: _hex('#122131'),
      surfaceContainerLow: _hex('#0D1C2D'),
      surfaceContainer: _hex('#122131'),
      surfaceContainerHigh: _hex('#1C2B3C'),
      surfaceContainerHighest: _hex('#273647'),
      onSurface: _hex('#D4E4FA'),
      onSurfaceVariant: _hex('#C7C6CD'),
      outlineVariant: _hex('#46464C'),
      error: _hex('#FFB4AB'),
      errorContainer: _hex('#93000A'),
      success: _hex('#10B981'),
      successContainer: _hex('#064E3B'),
      warning: _hex('#F59E0B'),
      warningContainer: _hex('#78350F'),
      scrim: _hex('#051424').withValues(alpha: 0.72),
      indigo: _hex('#6366F1'),
      indigoContainer: _hex('#312E81'),
      chart1: _hex('#6366F1'),
      chart2: _hex('#10B981'),
      chart3: _hex('#DDB7FF'),
      chart4: _hex('#64748B'),
      chartGrid: _hex('#273647'),
    );
  }

  /// Akshara Parent — warm light portal (#f8f9ff, friendly blue actions).
  static AksharaColorTokens _aksharaParent() {
    return AksharaColorTokens(
      primary: _hex('#0058BE'),
      onPrimary: _hex('#FFFFFF'),
      primaryContainer: _hex('#EFF4FF'),
      onPrimaryContainer: _hex('#004395'),
      secondary: _hex('#0E1C2D'),
      onSecondary: _hex('#FFFFFF'),
      secondaryContainer: _hex('#DCE9FF'),
      onSecondaryContainer: _hex('#3A485A'),
      tertiary: _hex('#009844'),
      onTertiary: _hex('#FFFFFF'),
      tertiaryContainer: _hex('#6BFF8F'),
      onTertiaryContainer: _hex('#005321'),
      surface: _hex('#FFFFFF'),
      surfaceContainerLow: _hex('#F8F9FF'),
      surfaceContainer: _hex('#E5EEFF'),
      surfaceContainerHigh: _hex('#DCE9FF'),
      surfaceContainerHighest: _hex('#D3E4FE'),
      onSurface: _hex('#0B1C30'),
      onSurfaceVariant: _hex('#44474C'),
      outlineVariant: _hex('#C4C6CD'),
      error: _hex('#BA1A1A'),
      errorContainer: _hex('#FFDAD6'),
      success: _hex('#009844'),
      successContainer: _hex('#6BFF8F'),
      warning: _hex('#F59E0B'),
      warningContainer: _hex('#FFFBEB'),
      scrim: _hex('#0B1C30').withValues(alpha: 0.4),
      indigo: _hex('#2170E4'),
      indigoContainer: _hex('#D8E2FF'),
      chart1: _hex('#0058BE'),
      chart2: _hex('#009844'),
      chart3: _hex('#2170E4'),
      chart4: _hex('#74777D'),
      chartGrid: _hex('#C4C6CD'),
    );
  }

  /// Student Pulse — gamified dark (#0b1326, emerald primary).
  static AksharaColorTokens _studentPulse() {
    return AksharaColorTokens(
      primary: _hex('#4EDEA3'),
      onPrimary: _hex('#003824'),
      primaryContainer: _hex('#10B981'),
      onPrimaryContainer: _hex('#00422B'),
      secondary: _hex('#6366F1'),
      onSecondary: _hex('#FFFFFF'),
      secondaryContainer: _hex('#3131C0'),
      onSecondaryContainer: _hex('#B0B2FF'),
      tertiary: _hex('#FFB95F'),
      onTertiary: _hex('#472A00'),
      tertiaryContainer: _hex('#E29100'),
      onTertiaryContainer: _hex('#523200'),
      surface: _hex('#171F33'),
      surfaceContainerLow: _hex('#131B2E'),
      surfaceContainer: _hex('#171F33'),
      surfaceContainerHigh: _hex('#222A3D'),
      surfaceContainerHighest: _hex('#2D3449'),
      onSurface: _hex('#DAE2FD'),
      onSurfaceVariant: _hex('#BBCABF'),
      outlineVariant: _hex('#3C4A42'),
      error: _hex('#FFB4AB'),
      errorContainer: _hex('#93000A'),
      success: _hex('#10B981'),
      successContainer: _hex('#064E3B'),
      warning: _hex('#F97316'),
      warningContainer: _hex('#7C2D12'),
      scrim: _hex('#0B1326').withValues(alpha: 0.72),
      indigo: _hex('#6366F1'),
      indigoContainer: _hex('#312E81'),
      chart1: _hex('#4EDEA3'),
      chart2: _hex('#6366F1'),
      chart3: _hex('#F59E0B'),
      chart4: _hex('#64748B'),
      chartGrid: _hex('#2D3449'),
    );
  }

  /// Classroom Command — teacher workspace (#131315, indigo + emerald).
  static AksharaColorTokens _classroomCommand() {
    return AksharaColorTokens(
      primary: _hex('#8083FF'),
      onPrimary: _hex('#07006C'),
      primaryContainer: _hex('#494BD6'),
      onPrimaryContainer: _hex('#E1E0FF'),
      secondary: _hex('#4EDEA3'),
      onSecondary: _hex('#003824'),
      secondaryContainer: _hex('#00A572'),
      onSecondaryContainer: _hex('#6FFBBE'),
      tertiary: _hex('#FF516A'),
      onTertiary: _hex('#67001B'),
      tertiaryContainer: _hex('#5B0017'),
      onTertiaryContainer: _hex('#FFDADB'),
      surface: _hex('#201F22'),
      surfaceContainerLow: _hex('#1C1B1D'),
      surfaceContainer: _hex('#201F22'),
      surfaceContainerHigh: _hex('#2A2A2C'),
      surfaceContainerHighest: _hex('#353437'),
      onSurface: _hex('#E5E1E4'),
      onSurfaceVariant: _hex('#C7C4D7'),
      outlineVariant: _hex('#464554'),
      error: _hex('#FFB4AB'),
      errorContainer: _hex('#93000A'),
      success: _hex('#4EDEA3'),
      successContainer: _hex('#00311F'),
      warning: _hex('#F59E0B'),
      warningContainer: _hex('#78350F'),
      scrim: _hex('#131315').withValues(alpha: 0.72),
      indigo: _hex('#C0C1FF'),
      indigoContainer: _hex('#494BD6'),
      chart1: _hex('#8083FF'),
      chart2: _hex('#4EDEA3'),
      chart3: _hex('#FF516A'),
      chart4: _hex('#908FA0'),
      chartGrid: _hex('#353437'),
    );
  }
}
