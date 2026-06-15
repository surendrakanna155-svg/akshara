import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/ai_content/ai_content_models.dart';
import 'package:akshara_erp/features/ai_content/ai_content_providers.dart';
import 'package:akshara_erp/features/ai_content/ai_content_screen.dart';
import 'package:akshara_erp/features/ai_content/ai_content_service.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAiProvider implements AiProvider {
  @override
  String get id => 'fake-ai';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    return const AiInferenceResponse(
      content: 'Generated content for Notice',
      provider: 'fake-ai',
      fromCache: false,
      usedFallback: false,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {}
}

class _FakeAiContentService extends AiContentService {
  _FakeAiContentService()
      : super(
          pipeline: AiInferencePipeline(
            provider: _FakeAiProvider(),
            cache: AiResponseCache(),
            telemetry: AiInferenceTelemetry(),
            rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
          ),
        );

  @override
  Future<AiGeneratedContent> generate(AiContentRequest request) async {
    return AiGeneratedContent(
      type: request.type,
      content: 'Generated content for ${request.type.label}',
      generatedAt: DateTime(2026, 1, 1),
    );
  }
}

void main() {
  testWidgets('generates content preview', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiContentServiceProvider.overrideWithValue(_FakeAiContentService()),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const AiContentScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(QaTestKeys.aiContentPromptField),
      'Announce summer camp schedule',
    );
    await tester.tap(find.byKey(QaTestKeys.aiContentGenerateButton));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.aiContentGeneratedCard), findsOneWidget);
    expect(find.byKey(QaTestKeys.aiContentGeneratedSnackbar), findsOneWidget);
  });
}
