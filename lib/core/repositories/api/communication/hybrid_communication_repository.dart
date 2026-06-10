import '../../../../features/notifications/notifications_models.dart';
import '../../interfaces/communication_repository.dart';
import '../../mock/mock_communication_repository.dart';
import '../../repository_query.dart';
import 'api_communication_repository.dart';

class HybridCommunicationRepository implements CommunicationRepository {
  HybridCommunicationRepository({
    required ApiCommunicationRepository api,
    required MockCommunicationRepository mock,
    required bool useApi,
  })  : _api = api,
        _mock = mock,
        _useApi = useApi;

  final ApiCommunicationRepository _api;
  final MockCommunicationRepository _mock;
  final bool _useApi;

  CommunicationRepository get _delegate => _useApi ? _api : _mock;

  @override
  Future<List<AppNotification>> getNotifications({
    required RepositoryQuery query,
  }) =>
      _delegate.getNotifications(query: query);

  @override
  Future<void> markNotificationRead({
    required RepositoryQuery query,
    required String notificationId,
  }) =>
      _delegate.markNotificationRead(
        query: query,
        notificationId: notificationId,
      );

  @override
  Future<void> markAllNotificationsRead({
    required RepositoryQuery query,
  }) =>
      _delegate.markAllNotificationsRead(query: query);

  @override
  Future<void> registerDeviceToken({
    required RepositoryQuery query,
    required String platform,
    required String token,
  }) =>
      _delegate.registerDeviceToken(
        query: query,
        platform: platform,
        token: token,
      );

  @override
  Future<void> unregisterDeviceToken({
    required RepositoryQuery query,
    required String token,
  }) =>
      _delegate.unregisterDeviceToken(query: query, token: token);

  @override
  Future<List<CommunicationTemplate>> getTemplates({
    required RepositoryQuery query,
  }) =>
      _delegate.getTemplates(query: query);

  @override
  Future<BroadcastResult> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequest request,
  }) =>
      _delegate.sendBroadcast(query: query, request: request);
}
