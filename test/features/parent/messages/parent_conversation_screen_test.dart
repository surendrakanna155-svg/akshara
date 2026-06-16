import 'package:akshara_erp/features/parent/messages/parent_conversation_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

Future<void> pumpParentScreen(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('ParentConversationScreen', () {
    testWidgets('renders thread and reply composer', (tester) async {
      await pumpParentScreen(
        tester,
        const ParentConversationScreen(threadId: 'parent_thread_1'),
      );

      expect(find.textContaining('Ravi Kumar'), findsWidgets);
      expect(
        find.textContaining(
          'Ravi was absent due to fever. Can we get class notes?',
        ),
        findsOneWidget,
      );
      expect(find.text('Reply'), findsWidgets);
      expect(find.text('Send'), findsOneWidget);
      expect(find.byType(AksharaEmptyState), findsNothing);
    });
  });
}

