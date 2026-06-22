import 'package:akshara_erp/features/intelligence/operations/operations_intelligence.dart';
import 'package:akshara_erp/features/intelligence/unified/unified_recommendation_intelligence.dart';
import 'package:akshara_erp/features/intelligence/management/intelligence_recommendation_navigation.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
      'navigateIntelligenceRecommendation routes fee collection to defaulters',
      (tester) async {
    late String? capturedLocation;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => navigateIntelligenceRecommendation(
                context,
                UnifiedRecommendationSource.feeCollection,
              ),
              child: const Text('Go'),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.financeDefaulters,
          builder: (context, state) {
            capturedLocation = state.uri.path;
            return const Scaffold(body: Text('Defaulters'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(capturedLocation, RouteNames.financeDefaulters);
  });

  testWidgets('navigateOperationsHint routes workflow hints to automation',
      (tester) async {
    late String? capturedLocation;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => navigateOperationsHint(
                context,
                OperationsHintKind.workflowAutomation,
              ),
              child: const Text('Go'),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.managementWorkflowAutomation,
          builder: (context, state) {
            capturedLocation = state.uri.path;
            return const Scaffold(body: Text('Workflow'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(capturedLocation, RouteNames.managementWorkflowAutomation);
  });
}
