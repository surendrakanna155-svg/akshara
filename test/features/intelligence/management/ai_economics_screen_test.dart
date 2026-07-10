import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:akshara_erp/features/copilot/copilot_provider.dart';
import 'package:akshara_erp/features/intelligence/management/ai_economics_screen.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AiEconomics _economics({
  int spendMicros = 640000000,
  int spendCapMicros = 1000000000,
  bool atSpendWarn = false,
  bool atSpendCap = false,
}) {
  return AiEconomics(
    monthStart: '2026-07-01T00:00:00.000Z',
    spendMicros: spendMicros,
    spendCapMicros: spendCapMicros,
    spendWarnRatio: 0.8,
    atSpendWarn: atSpendWarn,
    atSpendCap: atSpendCap,
    modelCalls: 812,
    fallbacks: 46,
    callsByOutcome: const {'ok': 780, 'refused': 32},
    callsBySurface: const {'copilot_chat': 540, 'quick_action': 180},
    cacheEntries: 340,
    cacheHits: 2210,
    tokensSaved: 1875000,
    cacheHitRatio: 0.73,
  );
}

Future<void> _pump(WidgetTester tester, AiEconomics economics) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        copilotCanUseProvider.overrideWithValue(true),
        copilotEconomicsFutureProvider.overrideWith((_) async => economics),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const AiEconomicsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders spend vs cap, model calls and cache hit ratio', (tester) async {
    await _pump(tester, _economics());

    expect(find.text('AI Usage & Cost'), findsOneWidget);
    expect(find.text('US\$640.00 of US\$1000.00'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('812'), findsOneWidget); // real model calls
    expect(find.text('46'), findsOneWidget); // governed fallbacks
    expect(find.text('73%'), findsOneWidget); // cache hit ratio
    expect(find.text('1875000'), findsOneWidget); // tokens saved
  });

  testWidgets('shows the warn state once spend reaches the warn ratio', (tester) async {
    await _pump(
      tester,
      _economics(spendMicros: 820000000, atSpendWarn: true),
    );

    expect(find.text('Near cap'), findsOneWidget);
    expect(find.text('US\$820.00 of US\$1000.00'), findsOneWidget);
    expect(find.textContaining('82% of the monthly cap'), findsOneWidget);
  });

  testWidgets('shows the at-cap state once spend reaches the cap', (tester) async {
    await _pump(
      tester,
      _economics(spendMicros: 1000000000, atSpendWarn: true, atSpendCap: true),
    );

    expect(find.text('At cap'), findsOneWidget);
  });

  testWidgets('an uncapped panel omits the progress bar and shows total spend only',
      (tester) async {
    await _pump(tester, _economics(spendCapMicros: 0));

    expect(find.text('US\$640.00'), findsOneWidget);
    expect(find.text('No monthly spend cap configured.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('re-checks RBAC: an unauthorized user sees the lock state, not data',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          copilotCanUseProvider.overrideWithValue(false),
          copilotEconomicsFutureProvider.overrideWith((_) async => _economics()),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const AiEconomicsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Copilot is not enabled for your role.'), findsOneWidget);
    expect(find.textContaining('US\$'), findsNothing);
  });

  testWidgets('a backend failure surfaces the error state, never a healthy \$0 panel',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          copilotCanUseProvider.overrideWithValue(true),
          copilotEconomicsFutureProvider.overrideWith(
            (_) async => throw Exception('backend down'),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const AiEconomicsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The monitoring surface must be honest about an outage (audit P1): an
    // error state with retry — NOT zeros that read as 'On track'.
    expect(find.byType(AksharaErrorState), findsOneWidget);
    expect(find.text('On track'), findsNothing);
    expect(find.textContaining('US\$0.00'), findsNothing);
  });
}
