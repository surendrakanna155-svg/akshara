import 'package:akshara_erp/shared/widgets/akshara_empty_illustration.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_section_empty.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaEmptyState', () {
    testWidgets('renders default title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaEmptyState(
              message: 'No students found for this filter.',
            ),
          ),
        ),
      );

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('No students found for this filter.'), findsOneWidget);
    });

    testWidgets('compact mode hides panel title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaEmptyState(
              message: 'No notices',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Nothing here yet'), findsNothing);
      expect(find.text('No notices'), findsOneWidget);
    });
  });

  group('AksharaErrorState', () {
    testWidgets('shows retry action', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: AksharaErrorState(
              message: 'Network unavailable',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('AksharaSectionEmpty', () {
    testWidgets('uses error tone for section error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: AksharaSectionError(
              message: 'Could not load schedule',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Could not load schedule'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(AksharaEmptyIllustration), findsOneWidget);
    });
  });

  group('AksharaLoadingState', () {
    testWidgets('shows caption when label is descriptive', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaLoadingState(
              semanticLabel: 'Loading finance dashboard',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading finance dashboard'), findsOneWidget);
    });
  });
}
