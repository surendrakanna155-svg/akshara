import 'package:akshara_erp/shared/widgets/akshara_queued_view.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-2 §2.4 — the amber "queued" ceremony must read as honestly *not*
/// confirmed: it states the receipt is issued on sync, and never claims success.
void main() {
  Widget host({VoidCallback? onPrimary}) {
    return MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: AksharaQueuedView(
          title: 'Payment queued',
          highlight: '₹5000',
          subtitle: 'Saved offline — the receipt is issued once it syncs.',
          caption: 'Cash · pending sync',
          primaryLabel: 'Done',
          onPrimary: onPrimary,
        ),
      ),
    );
  }

  testWidgets('renders the queued title, amount, and honest sync copy',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Payment queued'), findsOneWidget);
    expect(find.text('₹5000'), findsOneWidget);
    expect(
      find.text('Saved offline — the receipt is issued once it syncs.'),
      findsOneWidget,
    );
    // Deliberately NOT a green success tick.
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });

  testWidgets('the primary action fires the callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onPrimary: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
