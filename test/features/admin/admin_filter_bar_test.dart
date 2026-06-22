import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/admin/admin_filter_bar.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const filters = ['All', 'This period', 'Active'];

  Widget harness({
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: AdminFilterBar(
          filters: filters,
          selectedIndex: selected,
          onFilterSelected: onSelected,
        ),
      ),
    );
  }

  void useWidth(WidgetTester tester, double w) {
    tester.view.physicalSize = Size(w, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('AdminFilterBar', () {
    testWidgets('desktop shows inline chips, no mobile trigger', (tester) async {
      useWidth(tester, 1200);
      await tester.pumpWidget(harness(selected: 0, onSelected: (_) {}));
      await tester.pumpAndSettle();

      // All three chips render inline; the collapse trigger is absent.
      expect(find.text('This period'), findsOneWidget);
      expect(find.byKey(QaTestKeys.adminFilterTrigger), findsNothing);
    });

    testWidgets('phone collapses to a Filters trigger', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(harness(selected: 1, onSelected: (_) {}));
      await tester.pumpAndSettle();

      // Trigger replaces the inline chips and shows the active filter's label.
      expect(find.byKey(QaTestKeys.adminFilterTrigger), findsOneWidget);
      expect(find.text('This period'), findsOneWidget);
    });

    testWidgets('phone trigger opens a sheet and selection fires the callback',
        (tester) async {
      useWidth(tester, 390);
      int? picked;
      await tester
          .pumpWidget(harness(selected: 0, onSelected: (i) => picked = i));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.adminFilterTrigger));
      await tester.pumpAndSettle();

      // Sheet is open with every option listed.
      expect(find.byKey(QaTestKeys.adminFilterSheet), findsOneWidget);
      expect(find.byKey(QaTestKeys.adminFilterSheetOption('Active')),
          findsOneWidget);

      await tester
          .tap(find.byKey(QaTestKeys.adminFilterSheetOption('Active')));
      await tester.pumpAndSettle();

      // Callback got index 2 and the sheet closed.
      expect(picked, 2);
      expect(find.byKey(QaTestKeys.adminFilterSheet), findsNothing);
    });
  });
}
