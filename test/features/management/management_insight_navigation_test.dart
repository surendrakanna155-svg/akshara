import 'package:akshara_erp/features/management/management_insight_navigation.dart';
import 'package:akshara_erp/features/management/management_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('navigateManagementInsightAction routes analytics to student success',
      (tester) async {
    late String? capturedLocation;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => navigateManagementInsightAction(
                context,
                ManagementScreen.analytics,
              ),
              child: const Text('Go'),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.studentSuccessIntelligence,
          builder: (context, state) {
            capturedLocation = state.uri.path;
            return const Scaffold(body: Text('Student success'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(capturedLocation, RouteNames.studentSuccessIntelligence);
  });

  testWidgets('navigateManagementInsightAction routes finance to defaulters',
      (tester) async {
    late String? capturedLocation;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => navigateManagementInsightAction(
                context,
                ManagementScreen.finance,
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
}
