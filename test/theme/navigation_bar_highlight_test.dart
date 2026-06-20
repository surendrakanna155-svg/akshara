import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX Batch 2 — the selected bottom-nav icon sits INSIDE the primaryContainer
/// indicator pill, so it must use onPrimaryContainer for contrast. The old
/// `primary`-on-`primaryContainer` pairing was the washed-out highlight bug.
void main() {
  for (final entry in {
    'light': AksharaAppTheme.light(),
    'dark': AksharaAppTheme.dark(),
  }.entries) {
    final theme = entry.value;
    final scheme = theme.colorScheme;
    final iconTheme = theme.navigationBarTheme.iconTheme!;

    test('${entry.key}: selected nav icon uses onPrimaryContainer', () {
      final selected = iconTheme.resolve({WidgetState.selected})!;
      expect(selected.color, scheme.onPrimaryContainer);
    });

    test('${entry.key}: unselected nav icon uses onSurfaceVariant', () {
      final unselected = iconTheme.resolve(<WidgetState>{})!;
      expect(unselected.color, scheme.onSurfaceVariant);
    });

    test('${entry.key}: indicator pill is primaryContainer', () {
      expect(theme.navigationBarTheme.indicatorColor, scheme.primaryContainer);
    });
  }
}
