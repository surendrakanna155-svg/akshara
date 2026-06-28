@TestOn('mac-os')
library;

import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_providers.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_provider.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_screen.dart';
import 'package:akshara_erp/features/director/director_dashboard_screen.dart';
import 'package:akshara_erp/features/finance/dashboard/finance_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// Instant AI provider for golden capture. The default `StubAiProvider` adds a
/// 120ms `Future.delayed`; the director dashboard's executive-summary call leaves
/// that timer pending past the golden capture (tripping "Timer still pending")
/// and makes the summary non-deterministic. This returns a fixed reply with no
/// delay so the director surface settles deterministically.
class _InstantAiProvider implements AiProvider {
  @override
  String get id => 'golden-instant-stub';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    return const AiInferenceResponse(
      content: 'Portfolio steady; attendance and collections on track.',
      provider: 'golden-instant-stub',
      fromCache: false,
      usedFallback: true,
      model: 'golden-instant-stub',
      latencyMs: 0,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    final response = await complete(request);
    yield AiInferenceStreamChunk(
      delta: response.content,
      done: true,
      provider: id,
    );
  }
}

/// QW3 · QA-F-063 — Golden baselines for the key director/finance/admissions
/// dashboards across the three canonical viewports (390 / 428 / 834) plus a dark
/// mode capture. Extends the existing ERP dashboard golden coverage
/// (test/golden/erp_dashboards_golden_test.dart) to the finance, admissions and
/// director surfaces that had no multi-viewport / dark baselines.
void main() {
  group('QA-F-063 · key dashboard goldens', () {
    final cases = <({String prefix, Widget screen})>[
      (prefix: 'qw3_finance_dashboard', screen: const FinanceDashboardScreen()),
      (
        prefix: 'qw3_admissions_dashboard',
        screen: const AdmissionsDashboardScreen()
      ),
      (prefix: 'qw3_director_dashboard', screen: const DirectorDashboardScreen()),
    ];

    // Keep the admissions view-state stable (non-loading) for deterministic
    // captures; other dashboard loading flags are handled by the helper. The
    // instant AI provider removes the director executive-summary timer/jitter.
    final stableOverrides = <Override>[
      admissionsDashboardLoadingProvider.overrideWith((ref) => false),
      aiProviderProvider.overrideWith((ref) => _InstantAiProvider()),
    ];

    for (final testCase in cases) {
      // Light mode across all three canonical viewports.
      for (final viewport in GoldenViewports.all) {
        testWidgets('${testCase.prefix} renders at ${viewport.label}',
            (tester) async {
          await pumpGoldenErpScreen(
            tester,
            screen: testCase.screen,
            viewport: viewport.size,
            extraOverrides: stableOverrides,
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              goldenFileName(testCase.prefix, viewport.label),
            ),
          );
        });
      }

      // Dark mode at the primary mobile viewport.
      testWidgets('${testCase.prefix} renders in dark mode', (tester) async {
        await pumpGoldenErpScreen(
          tester,
          screen: testCase.screen,
          viewport: GoldenViewports.mobile390,
          extraOverrides: stableOverrides,
          dark: true,
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            goldenFileName('dark_${testCase.prefix}', '390x844'),
          ),
        );
      });
    }
  });
}
