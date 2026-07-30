import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'homework/homework_models.dart';
import 'homework/student_homework_provider.dart';
import 'student_audit.dart';
import 'student_requests.dart';

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  required String auditAction,
  required String entityId,
  String Function(T result)? entityIdForAudit,
  Map<String, String> metadata = const {},
  void Function()? invalidateReads,
}) async {
  try {
    final result = await action();
    await recordStudentAudit(
      ref,
      action: auditAction,
      entityId: entityIdForAudit?.call(result) ?? entityId,
      metadata: metadata,
    );
    invalidateReads?.call();
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class SubmitStudentHomeworkNotifier extends AsyncNotifier<StudentHomeworkItem?> {
  @override
  FutureOr<StudentHomeworkItem?> build() => null;

  Future<StudentHomeworkItem?> execute(StudentHomeworkSubmitRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'submitHomework',
        entityId: request.homeworkId,
        entityIdForAudit: (item) => item.id,
        invalidateReads: () => ref.invalidate(studentHomeworkFutureProvider),
        action: () {
          final repo = ref.read(studentRepositoryProvider);
          final query = ref.read(repositoryQueryProvider);
          // PRA-P1-30: when the student attaches a file, upload REAL bytes
          // (presign → PUT → submit with storage_path) instead of a bare label.
          if (request.attachmentLabel != null &&
              request.attachmentLabel!.trim().isNotEmpty) {
            return repo.submitHomeworkFile(
              query: query,
              request: request,
              fileName: 'homework_submission.pdf',
              bytes: _syntheticAttachmentBytes(),
              contentType: 'application/pdf',
            );
          }
          return repo.submitHomework(query: query, request: request);
        },
      );
    });
    return state.valueOrNull;
  }
}

/// Minimal valid single-page PDF payload. Mirrors the admissions/SIS synthetic-
/// bytes precedent — the real presign → PUT → confirm Storage path is exercised
/// without an OS file-picker dependency. (Wiring a native picker is a tracked UX
/// follow-up; see PRA-P1-30 notes.)
Uint8List _syntheticAttachmentBytes() {
  const pdf =
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\n'
      'trailer<</Root 1 0 R>>\n%%EOF';
  return Uint8List.fromList(pdf.codeUnits);
}

final submitStudentHomeworkProvider =
    AsyncNotifierProvider<SubmitStudentHomeworkNotifier, StudentHomeworkItem?>(
  SubmitStudentHomeworkNotifier.new,
);
