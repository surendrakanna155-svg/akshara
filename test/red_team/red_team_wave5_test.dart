// Red Team Wave 5 — client input bound (RT-32). The backend bounds (RT-31/32/33)
// and the connection pool (RT-35) are proven in supabase deno tests + the live
// cert; this proves the shared form field caps text entry.
import 'package:akshara_erp/shared/forms/akshara_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RT-32 AksharaFormField caps single-line input at the default',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AksharaFormField(label: 'Name', controller: controller),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'x' * 5000);
    expect(controller.text.length, 1000, reason: 'single-line default cap');
    // No visible character counter (bound stays invisible until reached).
    expect(find.textContaining('/1000'), findsNothing);
  });

  testWidgets('RT-32 AksharaFormField honours an explicit maxLength',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AksharaFormField(
            label: 'Code',
            controller: controller,
            maxLength: 12,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'A' * 100);
    expect(controller.text.length, 12);
  });
}
