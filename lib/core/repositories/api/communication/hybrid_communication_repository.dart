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
  Future<CommunicationTemplate> createTemplate({
    required RepositoryQuery query,
    required CreateCommunicationTemplateRequest request,
  }) =>
      _delegate.createTemplate(query: query, request: request);

  @override
  Future<CommunicationTemplate> updateTemplate({
    required RepositoryQuery query,
    required String templateId,
    required UpdateCommunicationTemplateRequest request,
  }) =>
      _delegate.updateTemplate(
        query: query,
        templateId: templateId,
        request: request,
      );

  @override
  Future<List<BroadcastHistoryItem>> listBroadcastHistory({
    required RepositoryQuery query,
  }) =>
      _delegate.listBroadcastHistory(query: query);

  @override
  Future<BroadcastResult> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequest request,
  }) =>
      _delegate.sendBroadcast(query: query, request: request);

  @override
  Future<BroadcastDeliveryReport> getBroadcastReport({
    required RepositoryQuery query,
    required String broadcastId,
  }) =>
      _delegate.getBroadcastReport(query: query, broadcastId: broadcastId);

  @override
  Future<int> resendBroadcastToUnread({
    required RepositoryQuery query,
    required String broadcastId,
  }) =>
      _delegate.resendBroadcastToUnread(query: query, broadcastId: broadcastId);

  @override
  Future<List<AudienceSegment>> listAudienceSegments({
    required RepositoryQuery query,
  }) =>
      _delegate.listAudienceSegments(query: query);

  @override
  Future<AudienceSegment> createAudienceSegment({
    required RepositoryQuery query,
    required String name,
    required String audienceType,
    String? className,
    String? sectionName,
  }) =>
      _delegate.createAudienceSegment(
        query: query,
        name: name,
        audienceType: audienceType,
        className: className,
        sectionName: sectionName,
      );

  @override
  Future<void> deleteAudienceSegment({
    required RepositoryQuery query,
    required String id,
  }) =>
      _delegate.deleteAudienceSegment(query: query, id: id);

  @override
  Future<void> acknowledgeNotification({
    required RepositoryQuery query,
    required String deliveryId,
  }) =>
      _delegate.acknowledgeNotification(query: query, deliveryId: deliveryId);
}
