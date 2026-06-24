import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_provider.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/entitlements/plan_badge.dart';
import 'package:akshara_erp/features/entitlements/plan_entitlements_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake subscription notifier returning a fixed resolved subscription.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier(this._value);
  final ResolvedSubscription _value;
  @override
  ResolvedSubscription build() => _value;
}

ResolvedSubscription _trial() => ResolvedSubscription(
      planSlug: 'trial',
      planName: 'Trial',
      tierRank: 0,
      status: SubscriptionStatus.trial,
      entitlements: const [],
      trialEndsAt: DateTime.now().add(const Duration(days: 20, hours: 1)),
    );

ResolvedSubscription _professional() => const ResolvedSubscription(
      planSlug: 'professional',
      planName: 'Professional',
      tierRank: 2,
      status: SubscriptionStatus.active,
      entitlements: [
        EntitlementSlugs.transport,
        EntitlementSlugs.hostel,
        EntitlementSlugs.library,
        EntitlementSlugs.inventory,
        EntitlementSlugs.alumni,
        EntitlementSlugs.hrPayroll,
        EntitlementSlugs.multiBranch,
        EntitlementSlugs.parentInsights,
      ],
    );

Future<void> _pumpScreen(WidgetTester tester, ResolvedSubscription sub) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionProvider.overrideWith(() => _FakeSubscriptionNotifier(sub)),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const PlanEntitlementsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PlanEntitlementsScreen — Trial', () {
    testWidgets('shows plan, trial days, locked modules and WhatsApp CTA',
        (tester) async {
      await _pumpScreen(tester, _trial());

      expect(find.byKey(QaTestKeys.planEntitlementsScreen), findsOneWidget);
      expect(find.text('Trial'), findsWidgets);
      // Trial days remaining surfaced.
      expect(find.byKey(QaTestKeys.planTrialRemainingLabel), findsOneWidget);
      expect(find.textContaining('remaining in trial'), findsOneWidget);
      // Optional modules are shown locked (never hidden) with upgrade message.
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Upgrade to unlock'), findsWidgets);
      expect(find.text('Locked'), findsWidgets);
      // WhatsApp upgrade CTA present.
      expect(find.byKey(QaTestKeys.planUpgradeWhatsappButton), findsOneWidget);
      expect(find.text('Upgrade on WhatsApp'), findsOneWidget);
    });
  });

  group('PlanEntitlementsScreen — Professional', () {
    testWidgets('ops modules unlocked; trust org still locked; no trial label',
        (tester) async {
      await _pumpScreen(tester, _professional());

      expect(find.byKey(QaTestKeys.planNameLabel), findsOneWidget);
      expect(find.text('Professional'), findsWidgets);
      // No trial countdown for a paid plan.
      expect(find.byKey(QaTestKeys.planTrialRemainingLabel), findsNothing);
      // Transport included → its description rather than the upgrade prompt.
      expect(find.text('Routes, vehicles & tracking'), findsOneWidget);
      // Trust / Organization is Enterprise-only → still locked here.
      expect(find.text('Trust / Organization'), findsOneWidget);
      expect(find.text('Locked'), findsWidgets);
    });
  });

  group('PlanBadge visibility', () {
    testWidgets('renders plan name when entitlement layer is enabled',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementApiEnabledProvider.overrideWithValue(true),
            subscriptionProvider
                .overrideWith(() => _FakeSubscriptionNotifier(_professional())),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const Scaffold(body: PlanBadge()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Professional'), findsOneWidget);
    });

    testWidgets('renders nothing when entitlement layer is disabled',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementApiEnabledProvider.overrideWithValue(false),
            subscriptionProvider
                .overrideWith(() => _FakeSubscriptionNotifier(_trial())),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const Scaffold(body: PlanBadge()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trial'), findsNothing);
    });
  });
}
