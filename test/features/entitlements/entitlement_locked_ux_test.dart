import 'package:akshara_erp/core/entitlements/entitlement_provider.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/features/copilot/copilot_capability_filter.dart';
import 'package:akshara_erp/features/entitlements/entitlement_module_gate.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Trial ceiling: no optional modules allowed.
final _trialCeiling = EntitlementResolver.planCeiling(const {});
// Professional ceiling: ops + multiBranch, no trust.
final _proCeiling = EntitlementResolver.planCeiling({
  'module.transport',
  'module.multi_branch',
});

void main() {
  group('G6a — EntitlementModuleGate', () {
    testWidgets('shows the locked/upgrade view when the module is plan-locked',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planCapabilityCeilingProvider.overrideWithValue(_trialCeiling),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const EntitlementModuleGate(
              module: AdminModule.transport,
              child: Text('TRANSPORT CONTENT'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TRANSPORT CONTENT'), findsNothing);
      expect(find.textContaining('is locked'), findsOneWidget);
      expect(find.text('Upgrade on WhatsApp'), findsOneWidget);
      expect(find.text('View plans'), findsOneWidget);
    });

    testWidgets('shows the real module when the plan allows it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planCapabilityCeilingProvider.overrideWithValue(_proCeiling),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const EntitlementModuleGate(
              module: AdminModule.transport,
              child: Text('TRANSPORT CONTENT'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TRANSPORT CONTENT'), findsOneWidget);
    });

    test('modulePlanLockedProvider reflects the ceiling', () {
      final container = ProviderContainer(overrides: [
        planCapabilityCeilingProvider.overrideWithValue(_proCeiling),
      ]);
      addTearDown(container.dispose);
      expect(container.read(modulePlanLockedProvider(AdminModule.transport)), isFalse);
      expect(container.read(modulePlanLockedProvider(AdminModule.hostel)), isTrue);
      // Core module never locked.
      expect(container.read(modulePlanLockedProvider(AdminModule.finance)), isFalse);
    });
  });

  group('G6c — copilot plan-locked message', () {
    const effectiveOff = SchoolCapabilities(transport: false);

    test('plan-locked topic → upgrade message (not "enable in config")', () {
      final msg = CopilotCapabilityFilter.disabledTopicMessage(
        userMessage: 'show me the bus routes',
        capabilities: effectiveOff,
        planCeiling: _trialCeiling, // plan does not include transport
      );
      expect(msg, isNotNull);
      expect(msg, contains('not included in your current plan'));
      expect(msg, contains('Plan & Entitlements'));
    });

    test('school-disabled (within plan) → enable-in-config message', () {
      final msg = CopilotCapabilityFilter.disabledTopicMessage(
        userMessage: 'show me the bus routes',
        capabilities: effectiveOff,
        planCeiling: _proCeiling, // plan allows transport; school turned it off
      );
      expect(msg, isNotNull);
      expect(msg, contains('disabled for this school'));
    });
  });
}
