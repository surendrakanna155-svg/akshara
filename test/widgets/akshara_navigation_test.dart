import 'package:akshara_erp/shared/widgets/akshara_navigation.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AksharaModuleSubNavTab', () {
    testWidgets('renders selected and unselected states', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                AksharaModuleSubNavTab(
                  label: 'Dashboard',
                  selected: true,
                  onTap: () {},
                ),
                AksharaModuleSubNavTab(
                  label: 'Reports',
                  selected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });
  });

  group('AksharaNavBrandHeader', () {
    testWidgets('shows brand title when expanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: AksharaNavBrandHeader(),
          ),
        ),
      );

      expect(find.text('Akshara ERP'), findsOneWidget);
    });
  });

  group('AksharaNavFilterChip', () {
    testWidgets('invokes onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: AksharaNavFilterChip(
              label: 'This month',
              selected: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('This month'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
