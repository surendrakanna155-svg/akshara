import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/shared/copy/akshara_copy.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-UX-1 slice 2d — copy/error dictionary + permission-as-its-own-state.
void main() {
  Future<void> pump(WidgetTester tester, ApiFailure failure) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: AksharaErrorState.fromFailure(failure, onRetry: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  group('failure → presentation kind', () {
    test('forbidden is permission; unauthorized is session; network is offline',
        () {
      expect(ApiFailureType.forbidden.kind, AksharaFailureKind.permission);
      expect(
          ApiFailureType.unauthorized.kind, AksharaFailureKind.sessionExpired);
      expect(ApiFailureType.network.kind, AksharaFailureKind.offline);
      expect(ApiFailureType.server.kind, AksharaFailureKind.error);
    });
  });

  group('AksharaErrorState renders permission as its own state', () {
    testWidgets('forbidden → permission title + NO retry (not a generic error)',
        (tester) async {
      await pump(
        tester,
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You do not have permission to perform this action.',
          code: 'FORBIDDEN',
        ),
      );
      expect(find.text(AksharaCopy.permissionTitle), findsOneWidget);
      expect(find.text(AksharaCopy.errorTitle), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('unauthorized → session-expired title', (tester) async {
      await pump(
        tester,
        const ApiFailure(
          type: ApiFailureType.unauthorized,
          message: 'Please sign in again.',
          code: 'UNAUTHORIZED',
        ),
      );
      expect(find.text(AksharaCopy.sessionExpiredTitle), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('server error → generic error title WITH retry', (tester) async {
      await pump(
        tester,
        const ApiFailure(
          type: ApiFailureType.server,
          message: 'Server error. Our team has been notified.',
          code: 'SERVER_ERROR',
        ),
      );
      expect(find.text(AksharaCopy.errorTitle), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
