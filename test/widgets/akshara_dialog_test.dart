import 'package:akshara_erp/shared/forms/akshara_form_field.dart';
import 'package:akshara_erp/shared/widgets/akshara_dialog.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaAlertDialog', () {
    testWidgets('renders title, icon, and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: AksharaAlertDialog(
              title: 'Create record',
              icon: Icons.add,
              content: const Text('Form body'),
              actions: [
                AksharaDialogActions(
                  confirmLabel: 'Save',
                  onCancel: () {},
                  onConfirm: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Create record'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('AksharaFormField', () {
    testWidgets('renders label and accepts input', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: AksharaFormField(
              label: 'Student name',
              controller: controller,
              required: true,
            ),
          ),
        ),
      );

      expect(find.text('Student name *'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Arjun');
      expect(controller.text, 'Arjun');
    });
  });

  group('showAksharaConfirmDialog', () {
    testWidgets('returns true when confirmed', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    result = await showAksharaConfirmDialog(
                      context,
                      title: 'Delete item',
                      message: 'This cannot be undone.',
                      destructive: true,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
