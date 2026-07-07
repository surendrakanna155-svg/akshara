import 'package:akshara_erp/shared/widgets/akshara_success_view.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-UX-1 — the shared success ceremony.

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(theme: AksharaAppTheme.light(), home: Scaffold(body: child)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AksharaSuccessView', () {
    testWidgets('renders title, highlight, subtitle, caption + both actions',
        (tester) async {
      var primaryTapped = false;
      var secondaryTapped = false;
      await _pump(
        tester,
        AksharaSuccessView(
          title: 'Payment successful',
          highlight: '₹1,200',
          subtitle: 'Receipt DPS-1',
          caption: 'Cash · 12 Jul 2026',
          primaryLabel: 'View receipt',
          onPrimary: () => primaryTapped = true,
          secondaryLabel: 'Back to fees',
          onSecondary: () => secondaryTapped = true,
        ),
      );

      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('₹1,200'), findsOneWidget);
      expect(find.text('Receipt DPS-1'), findsOneWidget);
      expect(find.text('Cash · 12 Jul 2026'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('View receipt'));
      await tester.tap(find.text('Back to fees'));
      expect(primaryTapped, isTrue);
      expect(secondaryTapped, isTrue);
    });

    testWidgets('omits optional lines + the secondary action when not provided',
        (tester) async {
      await _pump(
        tester,
        const AksharaSuccessView(title: 'Marks saved', primaryLabel: 'Done'),
      );

      expect(find.text('Marks saved'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing); // no secondary action
    });
  });
}
