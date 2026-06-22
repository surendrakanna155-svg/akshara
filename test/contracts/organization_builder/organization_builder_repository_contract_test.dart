import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/api/organization_builder/api_organization_builder_repository.dart';
import 'package:akshara_erp/core/repositories/api/organization_builder/remote/organization_builder_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/organization_builder_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_organization_builder_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Organization builder repository contract', () {
    late MockOrganizationBuilderRepository mockRepo;
    late ApiOrganizationBuilderRepository apiRepo;

    setUp(() {
      mockRepo = MockOrganizationBuilderRepository(
        pipeline: AiInferencePipeline(
          provider: _NoOpAiProvider(),
          cache: AiResponseCache(),
          telemetry: AiInferenceTelemetry(),
          rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
        ),
      );
      apiRepo = ApiOrganizationBuilderRepository(
        remote: OrganizationBuilderRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement OrganizationBuilderRepository', () {
      expect(mockRepo, isA<OrganizationBuilderRepository>());
      expect(apiRepo, isA<OrganizationBuilderRepository>());
    });

    test('listVerticalPacks returns four vertical packs', () async {
      final packs = await mockRepo.listVerticalPacks(
        query: RepositoryQuery.demo,
      );
      expect(packs, hasLength(4));
      expect(
        packs.map((pack) => pack.type).toSet(),
        containsAll(VerticalPackType.values),
      );
    });

    test('saveInterviewStep advances draft and enables preview', () async {
      const draftId = 'draft_contract_test';
      await mockRepo.saveInterviewStep(
        query: RepositoryQuery.demo,
        draftId: draftId,
        stepIndex: 6,
        answers: {
          'pack_id': 'pack_school',
          'identity_name': 'Akshara Test School',
          'review': 'confirmed',
        },
      );
      final draft = await mockRepo.getInterviewDraft(
        query: RepositoryQuery.demo,
        draftId: draftId,
      );
      expect(draft.status, InterviewDraftStatus.readyForPreview);
      expect(draft.organizationName, 'Akshara Test School');
    });

    test('generatePreview includes universal employee module flag', () async {
      const draftId = 'draft_preview_test';
      await mockRepo.saveInterviewStep(
        query: RepositoryQuery.demo,
        draftId: draftId,
        stepIndex: 0,
        answers: {
          'pack_id': 'pack_hospital',
          'identity_name': 'Akshara Care',
        },
      );
      final preview = await mockRepo.generatePreview(
        query: RepositoryQuery.demo,
        draftId: draftId,
      );
      expect(
        preview.modules.any((m) => m.id == kUniversalEmployeeModuleId),
        isTrue,
      );
    });
  });
}

class _NoOpAiProvider implements AiProvider {
  @override
  String get id => 'noop';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    return AiInferenceResponse(
      content: 'Enable analytics dashboard for leadership visibility.',
      provider: id,
      fromCache: false,
      usedFallback: false,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {}
}
