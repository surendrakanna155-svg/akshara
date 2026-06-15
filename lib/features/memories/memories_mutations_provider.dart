import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../phase5/phase5_models.dart';
import '../phase5/phase5_providers.dart';
import 'memories_audit.dart';

class CreateSchoolMemoryEventRequest {
  const CreateSchoolMemoryEventRequest({
    required this.title,
    required this.category,
    this.description,
  });

  final String title;
  final String category;
  final String? description;
}

class CreateSchoolMemoryEventNotifier
    extends AsyncNotifier<SchoolMemoryEvent?> {
  @override
  FutureOr<SchoolMemoryEvent?> build() => null;

  Future<SchoolMemoryEvent?> execute(
      CreateSchoolMemoryEventRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSchoolMemories(ref);
      try {
        final result =
            await ref.read(schoolMemoriesRepositoryProvider).createEvent(
                  query: ref.read(phase5QueryProvider),
                  title: request.title,
                  category: request.category,
                  description: request.description,
                );
        await recordMemoriesAudit(
          ref,
          type: AuditEventType.leadCreated,
          action: 'createSchoolMemoryEvent',
          entityId: result.id,
          metadata: {'category': request.category},
        );
        ref.invalidate(schoolMemoriesEventsProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createSchoolMemoryEventProvider =
    AsyncNotifierProvider<CreateSchoolMemoryEventNotifier, SchoolMemoryEvent?>(
  CreateSchoolMemoryEventNotifier.new,
);

class PublishSchoolMemoryEventNotifier
    extends AsyncNotifier<SchoolMemoryEvent?> {
  @override
  FutureOr<SchoolMemoryEvent?> build() => null;

  Future<SchoolMemoryEvent?> execute({required String eventId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSchoolMemories(ref);
      try {
        final result =
            await ref.read(schoolMemoriesRepositoryProvider).publishEvent(
                  query: ref.read(phase5QueryProvider),
                  eventId: eventId,
                );
        await recordMemoriesAudit(
          ref,
          action: 'publishSchoolMemoryEvent',
          entityId: eventId,
          metadata: {'status': result.status},
        );
        ref
          ..invalidate(schoolMemoriesEventsProvider)
          ..invalidate(schoolMemoryEventProvider(eventId));
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final publishSchoolMemoryEventProvider =
    AsyncNotifierProvider<PublishSchoolMemoryEventNotifier, SchoolMemoryEvent?>(
  PublishSchoolMemoryEventNotifier.new,
);
