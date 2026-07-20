import '../../../../features/support/domain/support_models.dart';
import '../../interfaces/support_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import 'mapper/support_mapper.dart';
import 'remote/support_remote_datasource.dart';

/// API implementation of [SupportRepository] — enabled via
/// [supportApiEnabledProvider].
class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository({
    required SupportRemoteDataSource remote,
    SupportMapper mapper = const SupportMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final SupportRemoteDataSource _remote;
  final SupportMapper _mapper;

  @override
  Future<SupportIncident> createIncident({
    required RepositoryQuery query,
    required CreateSupportIncidentInput input,
  }) async {
    final dto = await _remote.createIncident(
      query: query,
      body: {
        'title': input.title,
        'description': input.description,
        if (input.context != null) 'context': input.context,
      },
    );
    return _mapper.toIncident(dto);
  }

  @override
  Future<PaginatedResult<SupportIncident>> listIncidents({
    required RepositoryQuery query,
    SupportStatus? status,
  }) async {
    final dto = await _remote.listIncidents(
      query: query,
      status: status?.wire,
    );
    return PaginatedResult(
      items: _mapper.toIncidents(dto.items),
      page: dto.page,
      pageSize: dto.pageSize,
      total: dto.total,
      hasMore: dto.hasMore,
    );
  }

  @override
  Future<SupportIncidentDetail> getIncident({
    required RepositoryQuery query,
    required String incidentId,
  }) async {
    final dto = await _remote.getIncident(query: query, incidentId: incidentId);
    return _mapper.toDetail(dto);
  }

  @override
  Future<SupportMessage> postMessage({
    required RepositoryQuery query,
    required String incidentId,
    required String body,
  }) async {
    final dto = await _remote.postMessage(
      query: query,
      incidentId: incidentId,
      body: body,
    );
    return _mapper.toMessage(dto);
  }

  @override
  Future<SupportAttachment> uploadAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required AttachmentKind kind,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    // presign → PUT the bytes to the signed Storage URL → confirm the object.
    final presign = await _remote.presignAttachment(
      query: query,
      incidentId: incidentId,
      kind: kind.wire,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    await _remote.putBytes(
      signedUrl: presign.signedUrl,
      bytes: bytes,
      contentType: contentType,
    );
    final dto = await _remote.confirmAttachment(
      query: query,
      incidentId: incidentId,
      kind: kind.wire,
      storagePath: presign.storagePath,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    return _mapper.toAttachment(dto);
  }
}
