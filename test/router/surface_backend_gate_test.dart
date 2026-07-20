import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/router/surface_backend_gate.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// P0-CODE-2 — a backend-less surface is hidden ONLY in a live build whose API
/// flag is off; a local/mock build keeps it visible, and a wired flag shows it.
Future<bool> _hidden(
  WidgetTester tester,
  List<Override> overrides,
  String location,
) async {
  late bool result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          result = isBackendLessSurfaceHidden(ref, location);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('local/mock build (enableApiMode off) keeps all surfaces visible',
      (tester) async {
    final r = await _hidden(
      tester,
      [enableApiModeProvider.overrideWithValue(false)],
      '/sis/continuity',
    );
    expect(r, isFalse);
  });

  testWidgets('live build with the flag off HIDES the backend-less surface',
      (tester) async {
    // enableApiMode on, WORKFLOW/ACADEMIC-OPS/etc. flags default off in tests.
    for (final loc in const [
      '/management/workflow-automation',
      '/sis/promotion',
      '/sis/continuity',
      '/control-center/intelligence',
      '/platform-operations/alerts',
      '/multi-school/portfolio',
      '/healthcare',
      '/salon/dashboard',
      '/white-label/branding',
      '/control-center/white-label',
    ]) {
      final r = await _hidden(
        tester,
        [enableApiModeProvider.overrideWithValue(true)],
        loc,
      );
      expect(r, isTrue, reason: '$loc should be hidden in a live build');
    }
  });

  testWidgets('live build with the flag ON shows the surface', (tester) async {
    final r = await _hidden(
      tester,
      [
        enableApiModeProvider.overrideWithValue(true),
        continuityApiEnabledProvider.overrideWithValue(true),
      ],
      '/sis/continuity',
    );
    expect(r, isFalse);
  });

  testWidgets(
      'PRA-P0-14: promotion flag surfaces /sis/promotion but NOT the deferred '
      'reshuffle/section-balance surfaces', (tester) async {
    final overrides = [
      enableApiModeProvider.overrideWithValue(true),
      academicOperationsApiEnabledProvider.overrideWithValue(true),
    ];
    // The real, now-fixed promotion surface is revealed by the flag.
    expect(await _hidden(tester, overrides, '/sis/promotion'), isFalse);
    // The backend-less siblings stay hidden even with the academic-ops flag on —
    // they are decoupled onto an always-false provider.
    expect(await _hidden(tester, overrides, '/sis/reshuffle'), isTrue);
    expect(await _hidden(tester, overrides, '/sis/section-balance'), isTrue);
  });

  testWidgets('a normal (backed) route is never hidden', (tester) async {
    final r = await _hidden(
      tester,
      [enableApiModeProvider.overrideWithValue(true)],
      '/finance/dashboard',
    );
    expect(r, isFalse);
  });
}
