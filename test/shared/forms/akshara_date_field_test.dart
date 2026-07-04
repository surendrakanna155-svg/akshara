import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/shared/forms/akshara_date_field.dart';

/// XCT-3: free-text `YYYY-MM-DD` fields are replaced by a real date picker.
/// These tests pin the shared [AksharaDateField]: it is read-only (no free
/// text), tapping it opens [showDatePicker], and a selection is written back as
/// a canonical ISO string.
void main() {
  Widget host(TextEditingController controller) => MaterialApp(
        home: Scaffold(
          body: AksharaDateField(
            controller: controller,
            labelText: 'From date',
          ),
        ),
      );

  test('formatIso zero-pads to yyyy-MM-dd', () {
    expect(AksharaDateField.formatIso(DateTime(2026, 6, 5)), '2026-06-05');
    expect(AksharaDateField.formatIso(DateTime(2026, 12, 20)), '2026-12-20');
  });

  testWidgets('field is read-only (rejects typed free text)', (tester) async {
    final controller = TextEditingController(text: '2026-06-20');
    await tester.pumpWidget(host(controller));

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    // A read-only field cannot receive typed date input — the whole point of
    // XCT-3 (no more malformed free-text dates).
    expect(field.enabled, isTrue);
    // Entering text does nothing (read-only) — controller is unchanged.
    await tester.enterText(find.byType(TextFormField), '99-99-9999');
    expect(controller.text, '2026-06-20');
  });

  testWidgets('tapping opens the date picker and writes the chosen ISO date',
      (tester) async {
    final controller = TextEditingController(text: '2026-06-20');
    await tester.pumpWidget(host(controller));

    // Opens the Material date picker dialog.
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Pick the 15th and confirm.
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.text, '2026-06-15');
    expect(find.byType(DatePickerDialog), findsNothing);
  });
}
