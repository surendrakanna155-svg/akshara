import 'package:akshara_erp/shared/widgets/akshara_freshness_chip.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-1 slice 2b — A2 offline freshness chip.
void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    required bool online,
    bool showWhenLive = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aksharaFreshnessOnlineProvider.overrideWithValue(online),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: AksharaFreshnessChip(showWhenLive: showWhenLive),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('online → subtle Live chip', (tester) async {
    await pumpChip(tester, online: true);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Offline · saved data'), findsNothing);
  });

  testWidgets('offline → honest "Offline · saved data" chip', (tester) async {
    await pumpChip(tester, online: false);
    expect(find.text('Offline · saved data'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
  });

  testWidgets('showWhenLive:false hides the chip while online', (tester) async {
    await pumpChip(tester, online: true, showWhenLive: false);
    expect(find.byType(AksharaFreshnessChip), findsOneWidget);
    expect(find.text('Live'), findsNothing);
  });

  testWidgets('showWhenLive:false still surfaces the offline warning',
      (tester) async {
    await pumpChip(tester, online: false, showWhenLive: false);
    expect(find.text('Offline · saved data'), findsOneWidget);
  });
}
