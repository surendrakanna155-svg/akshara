@TestOn('mac-os')
library;

import 'package:akshara_erp/features/parent/events/parent_events_screen.dart';
import 'package:akshara_erp/features/parent/leave/parent_leave_screen.dart';
import 'package:akshara_erp/features/parent/notices/parent_notices_screen.dart';
import 'package:akshara_erp/features/parent/profile/parent_profile_screen.dart';
import 'package:akshara_erp/features/parent/ptm/parent_ptm_screen.dart';
import 'package:akshara_erp/features/parent/transport/parent_transport_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

/// DS V2 Phase 4 — flagship goldens for the PERIPHERAL parent-journey screens
/// (beyond the core fees/academics/messages modules). Each is rendered under the
/// parent persona theme at a tall viewport, Light + Dark, so the persona premium
/// canvas cohesion pass is captured while every flow, honest-state and callback
/// stays intact.
///
/// Screens omitted here render with a provider that never settles (infinite
/// progress) under default test providers — those keep their existing widget
/// tests + analyze coverage instead. See the notes at each batch.
void main() {
  const tall = Size(390, 1280);

  Future<void> pump(
    WidgetTester tester, {
    required Widget screen,
    required bool dark,
    List<Override> overrides = const [],
  }) async {
    suppressGoldenOverflowErrors();
    useGoldenViewport(tester, tall);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(overrides),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AksharaAppTheme.persona(
            brightness: dark ? Brightness.dark : Brightness.light,
            accent: AksharaPersonaAccent.parent,
          ),
          home: screen,
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('parent events · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentEventsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentEventsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_events_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent notices · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentNoticesScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentNoticesScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_notices_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent ptm · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentPtmScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentPtmScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_ptm_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent leave · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentLeaveScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentLeaveScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_leave_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent transport · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentTransportScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentTransportScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_transport_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent profile · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentProfileScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentProfileScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_profile_${mode.label}', '390x1280'),
        ),
      );
    });
  }
}
