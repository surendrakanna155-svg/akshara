import 'package:akshara_erp/shared/async/erp_async_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_skeleton.dart';
import 'package:akshara_erp/shared/widgets/mobile_async_body.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-1 slice 2a — AksharaSkeleton + skeleton loading in the shared wrappers.
void main() {
  // The shimmer (like the app's loading spinner) animates forever, so — per the
  // codebase convention for loading surfaces — advance frames with pump() rather
  // than pumpAndSettle(); a single pump is enough to build + assert the tree.
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('AksharaSkeleton presets', () {
    testWidgets('render skeleton boxes and settle (no forever animation)',
        (tester) async {
      await pump(tester, AksharaSkeleton.dashboard());
      // A dashboard skeleton composes multiple shimmer boxes.
      expect(find.byType(AksharaSkeletonBox), findsWidgets);
      // pumpAndSettle above proves the skeleton is test-stable.
    });

    testWidgets('list preset renders one row block per requested row',
        (tester) async {
      await pump(tester, AksharaSkeleton.list(rows: 4));
      expect(find.byType(AksharaSkeletonBox), findsWidgets);
    });

    testWidgets('primitives build without error', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            AksharaSkeleton.line(width: 80),
            AksharaSkeleton.circle(24),
            AksharaSkeleton.card(),
          ],
        ),
      );
      expect(find.byType(AksharaSkeletonBox), findsNWidgets(3));
    });
  });

  group('AksharaLoadingState skeleton slot', () {
    testWidgets('renders the skeleton instead of the spinner, keeps Loading a11y',
        (tester) async {
      await pump(
        tester,
        AksharaLoadingState(skeleton: AksharaSkeleton.list(rows: 3)),
      );
      expect(find.byType(AksharaSkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Type is unchanged so every find.byType(AksharaLoadingState) contract holds.
      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('falls back to the centered spinner when no skeleton',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(body: AksharaLoadingState()),
        ),
      );
      // Not pumpAndSettle: the spinner animates forever.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AksharaSkeletonBox), findsNothing);
    });
  });

  group('wrappers pass the skeleton through on loading', () {
    testWidgets('MobileAsyncBody loading → skeleton when provided',
        (tester) async {
      await pump(
        tester,
        MobileAsyncBody(
          isLoading: true,
          hasError: false,
          isEmpty: false,
          onRetry: () {},
          skeleton: AksharaSkeleton.dashboard(),
          builder: (_) => const Text('data'),
        ),
      );
      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.byType(AksharaSkeletonBox), findsWidgets);
      expect(find.text('data'), findsNothing);
    });

    testWidgets('ErpAsyncBody loading → skeleton when provided', (tester) async {
      await pump(
        tester,
        ErpAsyncBody<List<String>>(
          state: const ErpViewState<List<String>>(isLoading: true),
          onRetry: () {},
          loadingLabel: 'Loading',
          emptyMessage: 'empty',
          skeleton: AksharaSkeleton.list(rows: 3),
          builder: (data) => const Text('data'),
        ),
      );
      expect(find.byType(AksharaSkeletonBox), findsWidgets);
      expect(find.text('data'), findsNothing);
    });

    testWidgets('ErpAsyncBody without skeleton keeps the spinner fallback',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: ErpAsyncBody<List<String>>(
              state: const ErpViewState<List<String>>(isLoading: true),
              onRetry: () {},
              loadingLabel: 'Loading',
              emptyMessage: 'empty',
              builder: (data) => const Text('data'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AksharaSkeletonBox), findsNothing);
    });
  });
}
