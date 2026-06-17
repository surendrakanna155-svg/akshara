import 'package:akshara_erp/theme/m15_design_system.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 13 — programmatic safety gate markers for CI documentation.
void main() {
  group('M15 Phase 13 — safety markers', () {
    test('design system reached final certification version', () {
      expect(AksharaM15DesignSystem.version, '15.5.0');
      expect(AksharaM15DesignSystem.codename, isNotEmpty);
    });

    test('motion and accessibility modules are exported', () {
      expect(AksharaMotion.standard.inMilliseconds, greaterThan(0));
      expect(AksharaAccessibility.minContrastNormalText, 4.5);
    });
  });
}
