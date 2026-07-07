import 'package:akshara_erp/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-1 slice 2b — A3 tabular figures helper.
void main() {
  test('tabularFigures adds the FontFeature.tabularFigures feature', () {
    const base = TextStyle(fontSize: 16);
    final tab = base.tabularFigures;
    expect(tab.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('preserves any pre-existing font features', () {
    const base = TextStyle(fontFeatures: [FontFeature.enable('smcp')]);
    final tab = base.tabularFigures;
    expect(tab.fontFeatures, contains(const FontFeature.enable('smcp')));
    expect(tab.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('does not mutate the source style', () {
    const base = TextStyle(fontSize: 16);
    base.tabularFigures;
    expect(base.fontFeatures, isNull);
  });
}
