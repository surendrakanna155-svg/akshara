import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/color_tokens.dart';
import 'school_completion_providers.dart';

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final normalized = hex.replaceFirst('#', '');
  if (normalized.length != 6) return null;
  final value = int.tryParse('FF$normalized', radix: 16);
  return value == null ? null : Color(value);
}

/// Resolves school branding into [WhiteLabelThemeConfig] for [AksharaAppTheme].
final schoolBrandingThemeProvider = Provider<WhiteLabelThemeConfig?>((ref) {
  final branding = ref.watch(schoolBrandingProvider).valueOrNull;
  if (branding == null) return null;
  final primary = _parseHexColor(branding.primaryColor);
  if (primary == null) return null;
  return WhiteLabelThemeConfig(primary: primary);
});

/// School display name for login and splash surfaces.
final schoolDisplayNameProvider = Provider<String>((ref) {
  return ref.watch(schoolBrandingProvider).valueOrNull?.displayName ?? 'Akshara ERP';
});

final schoolLogoUrlProvider = Provider<String?>((ref) {
  return ref.watch(schoolBrandingProvider).valueOrNull?.logoUrl;
});
