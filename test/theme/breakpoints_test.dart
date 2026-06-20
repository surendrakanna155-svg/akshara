import 'package:akshara_erp/shared/layout/mobile_dashboard_layout.dart';
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

    test('canonical thresholds match the values feature code used to inline',
        () {
      // These are the single source of truth the per-screen private constants
      // and MobileDashboardLayout now forward to — guards against drift.
      expect(AksharaBreakpoints.tabletMinWidth, 768);
      expect(AksharaBreakpoints.largeMobileMinWidth, 428);
      expect(AksharaBreakpoints.narrowMobileMaxWidth, 360);
      expect(AksharaBreakpoints.compactContentMaxWidth, 480);
      expect(AksharaBreakpoints.readingContentMaxWidth, 640);
      // tabletMinWidth is exactly one past the mobile ceiling.
      expect(AksharaBreakpoints.tabletMinWidth, AksharaBreakpoints.mobileMax + 1);
    });

    test('tier helpers agree at the boundaries', () {
      expect(AksharaBreakpoints.isMobile(767), isTrue);
      expect(AksharaBreakpoints.isMobile(768), isFalse);
      expect(AksharaBreakpoints.isTabletUp(768), isTrue);
      expect(AksharaBreakpoints.isTabletUp(767), isFalse);
      expect(AksharaBreakpoints.isLargeMobileUp(428), isTrue);
      expect(AksharaBreakpoints.isLargeMobileUp(427), isFalse);
      expect(AksharaBreakpoints.isNarrowMobile(359), isTrue);
      expect(AksharaBreakpoints.isNarrowMobile(360), isFalse);
    });

    test('MobileDashboardLayout forwards to the canonical thresholds', () {
      expect(
        MobileDashboardLayout.tabletBreakpoint,
        AksharaBreakpoints.tabletMinWidth,
      );
      expect(
        MobileDashboardLayout.largeMobileBreakpoint,
        AksharaBreakpoints.largeMobileMinWidth,
      );
      expect(
        MobileDashboardLayout.tabletMaxContentWidth,
        AksharaBreakpoints.compactContentMaxWidth,
      );
      // isTablet uses the exact same boundary as the canonical helper.
      expect(MobileDashboardLayout.isTablet(768), isTrue);
      expect(MobileDashboardLayout.isTablet(767), isFalse);
    });
  });
}
