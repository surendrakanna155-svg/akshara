import 'package:akshara_erp/core/repositories/api/communication/api_communication_repository.dart';
import 'package:akshara_erp/core/repositories/api/communication/remote/communication_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/notifications/notifications_models.dart';
import 'package:akshara_erp/features/notifications/notifications_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// Fake repo that returns a fixed inbox and records acknowledge calls.
class _FakeCommunicationRepository extends ApiCommunicationRepository {
  _FakeCommunicationRepository()
      : super(remote: CommunicationRemoteDataSource(Dio()));

  final List<String> acknowledged = [];

  @override
  Future<List<AppNotification>> getNotifications({
    required RepositoryQuery query,
  }) async {
    return [
      AppNotification(
        id: 'ack-1',
        title: 'Exam schedule notice',
        preview: 'Please confirm you have read this.',
        timestamp: DateTime.now(),
        category: NotificationCategory.academic,
        requiresAck: true,
      ),
      AppNotification(
        id: 'plain-1',
        title: 'Holiday notice',
        preview: 'School closed Monday.',
        timestamp: DateTime.now(),
        category: NotificationCategory.announcement,
      ),
    ];
  }

  @override
  Future<void> acknowledgeNotification({
    required RepositoryQuery query,
    required String deliveryId,
  }) async {
    acknowledged.add(deliveryId);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeCommunicationRepository repo,
) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        communicationApiEnabledProvider.overrideWithValue(true),
        communicationRepositoryProvider.overrideWithValue(repo),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const NotificationsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Acknowledge button shows only for requiresAck && not acknowledged',
      (tester) async {
    final repo = _FakeCommunicationRepository();
    await _pump(tester, repo);

    // The ack notice shows an Acknowledge button; the plain notice does not.
    expect(
      find.byKey(QaTestKeys.notificationAcknowledgeButton('ack-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(QaTestKeys.notificationAcknowledgeButton('plain-1')),
      findsNothing,
    );
    expect(find.text('Acknowledged'), findsNothing);
  });

  testWidgets('tapping Acknowledge calls the repo and shows acknowledged state',
      (tester) async {
    final repo = _FakeCommunicationRepository();
    await _pump(tester, repo);

    await tester
        .tap(find.byKey(QaTestKeys.notificationAcknowledgeButton('ack-1')));
    await tester.pumpAndSettle();

    expect(repo.acknowledged, contains('ack-1'));
    // The button is replaced by the acknowledged state.
    expect(
      find.byKey(QaTestKeys.notificationAcknowledgeButton('ack-1')),
      findsNothing,
    );
    expect(find.text('Acknowledged'), findsOneWidget);
  });
}
