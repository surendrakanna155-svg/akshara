import 'package:akshara_erp/core/repositories/mock/mock_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:akshara_erp/features/copilot/copilot_provider.dart';
import 'package:akshara_erp/features/copilot/copilot_screen.dart';
import 'package:akshara_erp/features/copilot/copilot_screen_context.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/auth_test_overrides.dart';

/// Mock copilot repo whose reads succeed but whose [sendMessage] always throws,
/// simulating a network/500/RBAC failure on send.
class _FailingSendCopilotRepository extends MockCopilotRepository {
  @override
  Future<CopilotSendMessageResult> sendMessage({
    required RepositoryQuery query,
    required String sessionId,
    required String content,
    CopilotScreenContext? screenContext,
  }) async {
    throw Exception('send failed');
  }
}

void main() {
  testWidgets(
    'copilot surfaces an error and restores typed text when send fails',
    (tester) async {
      // Large surface so the message input + send button are on-screen and tappable.
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          authStateOverride(erpWidgetTestStaffAuth()),
          copilotRepositoryProvider
              .overrideWithValue(_FailingSendCopilotRepository()),
        ],
      );
      addTearDown(container.dispose);

      // A session must be selected for the input + send button to be enabled.
      container.read(copilotSelectedSessionIdProvider.notifier).state =
          'copilot_session_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: GoRouter(
              initialLocation: RouteNames.copilot,
              routes: [
                GoRoute(
                  path: RouteNames.copilot,
                  builder: (_, __) => const CopilotScreen(),
                ),
                GoRoute(
                  path: '/admin',
                  builder: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const typed = 'hello copilot';
      await tester.enterText(
        find.byKey(QaTestKeys.copilotMessageField),
        typed,
      );
      await tester.pump();

      await tester.tap(find.byKey(QaTestKeys.copilotSendButton));
      await tester.pump(); // start send (AsyncLoading)
      await tester.pump(const Duration(milliseconds: 50)); // resolve async failure
      await tester.pump(); // build the SnackBar

      // Error surfaced to the user.
      expect(find.byType(SnackBar), findsOneWidget);

      // The send notifier captured the error (precondition the screen relies on).
      final sendState = container.read(copilotSendMessageProvider);
      expect(sendState.hasError, isTrue);

      // The user's typed text was restored so they can retry.
      final field = tester.widget<TextField>(
        find.byKey(QaTestKeys.copilotMessageField),
      );
      expect(field.controller?.text, typed);
    },
  );
}
