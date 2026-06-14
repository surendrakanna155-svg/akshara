import '../../../../features/notifications/notifications_models.dart';
import '../../interfaces/communication_repository.dart';
import '../../repository_query.dart';
import 'dto/communication_dto.dart';
import 'remote/communication_api_paths.dart';
import 'remote/communication_remote_datasource.dart';

class ApiCommunicationRepository implements CommunicationRepository {
  ApiCommunicationRepository({
    required CommunicationRemoteDataSource remote,
    CommunicationMapper? mapper,
    this.notificationsPath = CommunicationApiPaths.parentNotifications,
  })  : _remote = remote,
        _mapper = mapper ?? CommunicationMapper();

  final CommunicationRemoteDataSource _remote;
  final CommunicationMapper _mapper;
  final String notificationsPath;

  @override
  Future<List<AppNotification>> getNotifications({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchNotifications(
      query: query,
      path: notificationsPath,
    );
    return [for (final item in dto.items) _mapper.toNotification(item)];
  }

  @override
  Future<void> markNotificationRead({
    required RepositoryQuery query,
    required String notificationId,
  }) async {
    await _remote.markNotificationRead(
      query: query,
      notificationId: notificationId,
      path: _markReadPath,
    );
  }

  @override
  Future<void> markAllNotificationsRead({
    required RepositoryQuery query,
  }) async {
    await _remote.markAllNotificationsRead(
      query: query,
      path: _markAllReadPath,
    );
  }

  @override
  Future<void> registerDeviceToken({
    required RepositoryQuery query,
    required String platform,
    required String token,
  }) async {
    await _remote.registerDeviceToken(
      query: query,
      platform: platform,
      token: token,
      path: _deviceRegisterPath,
    );
  }

  @override
  Future<void> unregisterDeviceToken({
    required RepositoryQuery query,
    required String token,
  }) async {
    await _remote.unregisterDeviceToken(
      query: query,
      token: token,
      path: _deviceUnregisterPath,
    );
  }

  String get _markReadPath => notificationsPath.startsWith('/student')
      ? '/student/notifications/mark-read'
      : CommunicationApiPaths.parentMarkRead;

  String get _markAllReadPath => notificationsPath.startsWith('/student')
      ? '/student/notifications/mark-all-read'
      : CommunicationApiPaths.parentMarkAllRead;

  String get _deviceRegisterPath => notificationsPath.startsWith('/student')
      ? '/student/device-tokens/register'
      : CommunicationApiPaths.parentDeviceRegister;

  String get _deviceUnregisterPath => notificationsPath.startsWith('/student')
      ? '/student/device-tokens/unregister'
      : CommunicationApiPaths.parentDeviceUnregister;

  @override
  Future<List<CommunicationTemplate>> getTemplates({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchTemplates(query: query);
    return [for (final item in dto.items) _mapper.toTemplate(item)];
  }

  @override
  Future<CommunicationTemplate> createTemplate({
    required RepositoryQuery query,
    required CreateCommunicationTemplateRequest request,
  }) async {
    final dto = await _remote.createTemplate(
      query: query,
      request: CreateCommunicationTemplateRequestDto.fromDomain(request),
    );
    return _mapper.toTemplate(dto);
  }

  @override
  Future<CommunicationTemplate> updateTemplate({
    required RepositoryQuery query,
    required String templateId,
    required UpdateCommunicationTemplateRequest request,
  }) async {
    final dto = await _remote.updateTemplate(
      query: query,
      templateId: templateId,
      request: UpdateCommunicationTemplateRequestDto.fromDomain(request),
    );
    return _mapper.toTemplate(dto);
  }

  @override
  Future<List<BroadcastHistoryItem>> listBroadcastHistory({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.listBroadcastHistory(query: query);
    return [for (final item in dto.items) _mapper.toBroadcastHistoryItem(item)];
  }

  @override
  Future<BroadcastResult> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequest request,
  }) async {
    final dto = await _remote.sendBroadcast(
      query: query,
      request: BroadcastRequestDto.fromDomain(request),
    );
    return _mapper.toBroadcastResult(dto);
  }
}
