import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AksharaErrorState.fromFailure shows code and retry', (
    tester,
  ) async {
    const failure = ApiFailure(
      type: ApiFailureType.network,
      message: 'Unable to reach the server.',
      code: 'NETWORK',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: AksharaErrorState.fromFailure(
            failure,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Unable to reach the server.'), findsOneWidget);
    expect(find.text('Error code: NETWORK'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
