import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/evolution/parent_insights_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          evolutionRepositoryProvider
              .overrideWithValue(MockEvolutionRepository()),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const ParentInsightsScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state with generate action when no insights',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('No insights yet'), findsOneWidget);
    expect(find.text('Generate weekly'), findsWidgets);
    // Period choices are available in the generate card.
    expect(find.text('Weekly'), findsWidgets);
    expect(find.text('Exam prep'), findsOneWidget);
  });

  testWidgets('generating a weekly insight renders a premium summary card',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Generate weekly').last);
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    // Mock snapshot content surfaces in the sectioned card.
    expect(find.text('Recent summaries'), findsOneWidget);
    expect(find.text('Strengths'), findsOneWidget);
    expect(find.text('Consistent participation'), findsOneWidget);
    expect(find.text('Teacher remarks'), findsOneWidget);
  });
}
