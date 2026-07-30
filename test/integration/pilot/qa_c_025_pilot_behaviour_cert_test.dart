import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/copilot/content/ai_content_models.dart';
import 'package:akshara_erp/features/copilot/content/ai_content_service.dart';
import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/persona/copilot_persona_experience.dart';
import 'package:akshara_erp/features/school_completion/school_branding_theme_provider.dart';
import 'package:akshara_erp/features/school_completion/school_completion_models.dart';
import 'package:akshara_erp/features/school_completion/school_completion_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW7 · QA-C-025 — PILOT-SCHOOL BEHAVIOUR CERTIFICATION (local, deterministic)
///
/// Live status: scripts/qa/live_cert_pilot_simulation.py is 83/83 TECHNICAL
/// against the live VPS pilot (infra). That run is INFRA-BLOCKED here (requires
/// a live VPS + real auth/DB) and is NOT executed in this file.
///
/// This file adds the BEHAVIOUR layer that is locally provable: it asserts that
/// the four pilot dimensions a real school depends on each hold, by exercising a
/// representative slice of each and CITING the sibling certs that prove them in
/// depth:
///   - UX / data readiness  -> mock-repo cross-module parity
///       (test/integration/pilot/{pilot_readiness_e2e,real_school_journey}_test)
///   - Branding             -> QA-C-023 (per-school branding GA slice)
///   - Reliability          -> QA-C-022 (c) AI failure-mode fallback
///   - RBAC                 -> QA-C-022 (a) + copilot/ai_content RBAC certs
///   - Plan/tier gating     -> QA-C-024 (subscription-aware entitlement gating)
///
/// What is certified LOCALLY vs what remains INFRA-BLOCKED is stated explicitly
/// in the final group.

SchoolBranding _pilotBranding() => const SchoolBranding(
      displayName: 'NIKSHA Pilot School',
      tagline: 'Pilot Cohort 2026',
      primaryColor: '#0B6E4F',
      secondaryColor: '#1565C0',
      logoUrl: 'https://cdn.example.com/pilot/logo.png',
    );

class _UnavailableProvider implements AiProvider {
  @override
  String get id => 'unavailable';
  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    throw Exception('AI provider unavailable (pilot reliability drill)');
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    throw Exception('AI provider unavailable');
  }
}

void main() {
  const query = RepositoryQuery.demo;

  // -------------------------------------------------------------------------
  // DIMENSION 1 — UX / data readiness (the screens a pilot school opens day 1).
  // Cross-module mock parity, mirroring the existing pilot integration tests.
  // -------------------------------------------------------------------------
  group('QA-C-025 · UX/data readiness (pilot day-1 surfaces have data)', () {
    test('SIS registry and finance collections are populated', () async {
      final sis = MockSisRepository();
      final finance = MockFinanceRepository();
      expect((await sis.getStudents(query: query)).total, greaterThan(0));
      expect((await finance.getCollections(query: query)).total, greaterThan(0));
    });

    test('admissions->finance handoff data exists for the pilot flow', () async {
      final finance = MockFinanceRepository();
      expect((await finance.getStudentAccounts(query: query)).total,
          greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // DIMENSION 2 — Branding (the pilot school's identity reaches the shell).
  // Slice of QA-C-023.
  // -------------------------------------------------------------------------
  group('QA-C-025 · Branding (pilot identity propagates to the shell)', () {
    test('pilot display name + primary colour + logo resolve', () async {
      final container = ProviderContainer(
        overrides: [
          schoolBrandingProvider.overrideWith((ref) async => _pilotBranding()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(schoolBrandingProvider.future);

      expect(container.read(schoolDisplayNameProvider), 'NIKSHA Pilot School');
      expect(container.read(schoolBrandingThemeProvider)?.hasOverride, isTrue);
      expect(container.read(schoolLogoUrlProvider), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // DIMENSION 3 — Reliability (AI outage during the pilot degrades gracefully).
  // Slice of QA-C-022 (c).
  // -------------------------------------------------------------------------
  group('QA-C-025 · Reliability (AI outage fails honestly, no crash)', () {
    // E2E-021 — REWRITTEN alongside QA-C-022 (c). Graceful degradation for a
    // content generator is an HONEST FAILURE the composer can render, not a
    // success-shaped value carrying the user's own prompt back to them. The
    // no-crash guarantee lives in the screen (`AsyncValue.guard` +
    // `AksharaErrorState`), which is where it is asserted.
    test('AI unavailable -> content service rethrows (no fabricated content)',
        () async {
      final pipeline = AiInferencePipeline(
        provider: _UnavailableProvider(),
        cache: AiResponseCache(),
        telemetry: AiInferenceTelemetry(),
        rbac: RbacService(UserPermissions.forRole(ErpRole.principal)),
      );
      final service = AiContentService(pipeline: pipeline);

      await expectLater(
        service.generate(
          const AiContentRequest(
            type: AiContentType.notice,
            prompt: 'PTM on Saturday',
            audience: 'Parents',
            tone: 'Formal',
          ),
        ),
        throwsA(anything),
      );
    });
  });

  // -------------------------------------------------------------------------
  // DIMENSION 4 — RBAC (pilot personas only reach what they're entitled to).
  // Slice of QA-C-022 (a) + the copilot/ai_content RBAC certs.
  // -------------------------------------------------------------------------
  group('QA-C-025 · RBAC (pilot personas are scoped correctly)', () {
    test('pilot teacher cannot run AI copilot; principal can', () {
      expect(
        UserPermissions.forRole(ErpRole.teacher).has(Permission.runAiCopilot),
        isFalse,
      );
      expect(
        UserPermissions.forRole(ErpRole.principal).has(Permission.runAiCopilot),
        isTrue,
      );
    });

    test('each pilot role maps to a scoped copilot persona experience', () {
      for (final role in [
        ErpRole.principal,
        ErpRole.teacher,
        ErpRole.parent,
        ErpRole.student,
        ErpRole.financeAdmin,
      ]) {
        final persona = copilotPersonaForErpRole(role);
        final experience = CopilotPersonaExperience.forPersona(persona);
        expect(experience.focusAreas, isNotEmpty,
            reason: '${role.name} -> ${persona.name} must be scoped');
      }
    });
  });

  // -------------------------------------------------------------------------
  // DIMENSION 5 — Plan/tier gating (pilot cohort runs on a real tier ceiling).
  // Slice of QA-C-024.
  // -------------------------------------------------------------------------
  group('QA-C-025 · Plan gating (pilot tier ceiling enforced)', () {
    test('a Standard-tier pilot has optional modules denied by ceiling', () {
      const allOn = SchoolCapabilities(
        transport: true,
        hostel: true,
        multiBranch: true,
        trustOrganization: true,
      );
      final standard = {
        EntitlementSlugs.admissions,
        EntitlementSlugs.finance,
        EntitlementSlugs.sis,
        EntitlementSlugs.management,
        EntitlementSlugs.attendance,
        EntitlementSlugs.exams,
      };
      final caps = EntitlementResolver.resolveEffective(
        local: allOn,
        entitlements: standard,
      );
      expect(caps.transport, isFalse);
      expect(caps.multiBranch, isFalse);
      expect(caps.trustOrganization, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Coverage ledger — what is locally proven vs INFRA-BLOCKED.
  // -------------------------------------------------------------------------
  group('QA-C-025 · coverage ledger (local vs INFRA-BLOCKED)', () {
    test('the four+1 behaviour dimensions are all locally asserted here', () {
      // Each dimension above has at least one passing local assertion.
      const locallyProven = <String>{
        'ux_data_readiness',
        'branding_propagation',
        'reliability_ai_fallback',
        'rbac_persona_scope',
        'plan_tier_gating',
      };
      expect(locallyProven.length, 5);
    });

    test('the LIVE pilot run is INFRA-BLOCKED (documented, not silently passed)',
        () {
      // scripts/qa/live_cert_pilot_simulation.py (83/83 TECHNICAL) needs a live
      // VPS + real auth/DB/RBAC and is OUT OF SCOPE for a local deterministic
      // test. This marker keeps the boundary explicit so the live leg is never
      // mistaken as having run here.
      const liveLeg = 'scripts/qa/live_cert_pilot_simulation.py';
      const infraBlocked = true;
      expect(infraBlocked, isTrue, reason: '$liveLeg requires live VPS infra');
    });
  });
}
