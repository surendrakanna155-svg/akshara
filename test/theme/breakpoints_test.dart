import 'package:akshara_erp/theme/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaBreakpoints', () {
    test('maps widths to layout breakpoints', () {
      expect(
        AksharaBreakpoints.fromWidth(390),
        LayoutBreakpoint.mobile,
      );
      expect(
        AksharaBreakpoints.fromWidth(834),
        LayoutBreakpoint.tablet,
      );
      expect(
        AksharaBreakpoints.fromWidth(1440),
        LayoutBreakpoint.desktop,
      );
    });

    test('exposes desktop content max width for 1440 grid', () {
      expect(AksharaBreakpoints.desktopContentMaxWidth, 1136);
      expect(AksharaBreakpoints.desktopFrameWidth, 1440);
    });
  });
}
