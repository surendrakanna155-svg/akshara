import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/shared/widgets/akshara_navigation.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 8 screens — comfortably more than the 4 inline slots, so the phone layout
  // must collapse the tail into "More".
  const labels = ['Dashboard', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight'];

  Widget harness({required int selected, double width = 390}) {
    return MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AksharaModuleSubNav(
              moduleKey: 'finance',
              semanticsLabel: 'Finance module navigation',
              items: [
                for (var i = 0; i < labels.length; i++)
                  AksharaModuleSubNavItem(
                    itemKey: QaTestKeys.moduleSubNavTab('finance', labels[i]),
                    label: labels[i],
                    selected: i == selected,
                    onTap: () {},
                  ),
              ],
            ),
          ),
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

  group('AksharaModuleSubNav', () {
    testWidgets('phone collapses overflow behind a More button', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(harness(selected: 0));
      await tester.pumpAndSettle();

      // First 4 stay inline; the rest are folded away.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Four'), findsOneWidget);
      expect(find.text('Five'), findsNothing);
      expect(find.text('Eight'), findsNothing);

      // The overflow cue is present.
      expect(find.byKey(QaTestKeys.moduleSubNavMore('finance')), findsOneWidget);
    });

    testWidgets('More button opens a sheet listing the overflow screens',
        (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(harness(selected: 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.moduleSubNavMore('finance')));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.moduleSubNavSheet('finance')), findsOneWidget);
      expect(find.text('Five'), findsOneWidget);
      expect(find.text('Eight'), findsOneWidget);
    });

    testWidgets('a selected overflow screen is swapped into the inline strip',
        (tester) async {
      useWidth(tester, 390);
      // 'Seven' is index 6 — past the 4 inline slots.
      await tester.pumpWidget(harness(selected: 6));
      await tester.pumpAndSettle();

      // The active screen stays visible without opening the sheet.
      expect(find.text('Seven'), findsOneWidget);
      // The More button is still there for the remaining overflow.
      expect(find.byKey(QaTestKeys.moduleSubNavMore('finance')), findsOneWidget);
    });

    testWidgets('tablet keeps every tab inline with no More button',
        (tester) async {
      useWidth(tester, 900);
      await tester.pumpWidget(harness(selected: 0, width: 900));
      await tester.pumpAndSettle();

      expect(find.text('Five'), findsOneWidget);
      expect(find.text('Eight'), findsOneWidget);
      expect(find.byKey(QaTestKeys.moduleSubNavMore('finance')), findsNothing);
    });
  });
}
