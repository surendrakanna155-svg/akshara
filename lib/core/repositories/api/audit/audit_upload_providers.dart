import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audit/audit_event.dart';
import '../../../audit/audit_upload_service.dart';
import '../../../network/dio_provider.dart';
import '../../repository_config.dart';
import 'dto/audit_batch_upload_dto.dart';
import 'remote/audit_remote_datasource.dart';

final auditRemoteDataSourceProvider = Provider<AuditRemoteDataSource>((ref) {
  return AuditRemoteDataSource(ref.watch(dioProvider));
});

/// Resolves the audit batch uploader based on API feature flags.
AuditBatchUploader resolveAuditBatchUploader(Ref ref) {
  if (!isModuleApiEnabled(ref, auditApiEnabledProvider)) {
    return (_) async {
      throw UnimplementedError('Audit batch upload is not configured');
    };
  }

  final remote = ref.watch(auditRemoteDataSourceProvider);
  return (batch) async {
    await remote.uploadBatch(batch);
  };
}

/// Exported for contract tests validating request DTO shape.
AuditBatchUploadRequestDto buildAuditBatchRequest(List<AuditEvent> events) {
  return AuditBatchUploadRequestDto.fromEvents(events);
}
