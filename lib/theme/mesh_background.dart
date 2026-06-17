import 'package:flutter/material.dart';

/// M15.5 dashboard mesh atmosphere palettes (Stitch-aligned).
enum AksharaMeshPalette {
  management,
  finance,
  teacher,
  parent,
  student,
  intelligence,
  transport,
  director,
  admin,
  neutral,
}

/// Mesh gradient tokens aligned to Stitch reference PNG palettes (M15.5).
abstract final class AksharaMeshTokens {
  static List<Color> colors(AksharaMeshPalette palette, ColorScheme scheme) {
    return switch (palette) {
      AksharaMeshPalette.management => [
          const Color(0xFF6366F1).withValues(alpha: 0.18),
          const Color(0xFF2563EB).withValues(alpha: 0.10),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.finance => [
          const Color(0xFF6366F1).withValues(alpha: 0.14),
          const Color(0xFF14B8A6).withValues(alpha: 0.10),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.teacher => [
          const Color(0xFF8083FF).withValues(alpha: 0.16),
          const Color(0xFF4EDEA3).withValues(alpha: 0.10),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.parent => [
          const Color(0xFF0058BE).withValues(alpha: 0.12),
          const Color(0xFF93C5FD).withValues(alpha: 0.18),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.student => [
          const Color(0xFF4EDEA3).withValues(alpha: 0.14),
          const Color(0xFF6366F1).withValues(alpha: 0.12),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.intelligence => [
          const Color(0xFFDDB7FF).withValues(alpha: 0.14),
          const Color(0xFF6366F1).withValues(alpha: 0.12),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.transport => [
          const Color(0xFF2563EB).withValues(alpha: 0.12),
          const Color(0xFF14B8A6).withValues(alpha: 0.10),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.director => [
          const Color(0xFF6366F1).withValues(alpha: 0.16),
          const Color(0xFF8B5CF6).withValues(alpha: 0.08),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.admin => [
          const Color(0xFF6366F1).withValues(alpha: 0.14),
          const Color(0xFF051424).withValues(alpha: 0.08),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
      AksharaMeshPalette.neutral => [
          scheme.primary.withValues(alpha: 0.10),
          scheme.tertiary.withValues(alpha: 0.06),
          scheme.surfaceContainerLow.withValues(alpha: 0),
        ],
    };
  }
}
