import 'package:akshara_erp/features/copilot/settings/ai_access_mode.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences_provider.dart';
import 'package:akshara_erp/theme/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveEffectiveAiAccessMode', () {
    test('auto defaults mobile to bottom nav center', () {
      expect(
        resolveEffectiveAiAccessMode(AiAccessMode.auto, LayoutBreakpoint.mobile),
        AiAccessMode.bottomNavCenter,
      );
    });

    test('auto defaults desktop to sidebar entry', () {
      expect(
        resolveEffectiveAiAccessMode(AiAccessMode.auto, LayoutBreakpoint.desktop),
        AiAccessMode.sidebarEntry,
      );
    });

    test('explicit mode is preserved', () {
      expect(
        resolveEffectiveAiAccessMode(AiAccessMode.appBarAction, LayoutBreakpoint.mobile),
        AiAccessMode.appBarAction,
      );
    });
  });

  group('access visibility helpers', () {
    test('optional floating bubble shows dock on any mode', () {
      expect(
        shouldShowFloatingAiDock(
          prefs: const AiAccessPreferences(floatingBubbleEnabled: true),
          breakpoint: LayoutBreakpoint.desktop,
        ),
        isTrue,
      );
    });

    test('admin sidebar maps mobile bottom nav to drawer slot', () {
      expect(
        shouldShowAdminSidebarAiEntry(
          prefs: const AiAccessPreferences(mode: AiAccessMode.auto),
          breakpoint: LayoutBreakpoint.mobile,
        ),
        isTrue,
      );
    });
  });

  group('AiAccessPreferences serialization', () {
    test('round-trips JSON', () {
      const original = AiAccessPreferences(
        mode: AiAccessMode.bottomNavCenter,
        floatingBubbleEnabled: true,
      );
      final restored = AiAccessPreferences.fromJson(original.toJson());
      expect(restored.mode, original.mode);
      expect(restored.floatingBubbleEnabled, isTrue);
    });
  });
}
