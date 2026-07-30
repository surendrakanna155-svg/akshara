import 'package:akshara_erp/core/onboarding/startup_onboarding_provision_store.dart';
import 'package:akshara_erp/core/onboarding/tenant_onboarding_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_startup_onboarding_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_models.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tenantA = 'tenant_a';
  const tenantB = 'tenant_b';
  const queryA = RepositoryQuery(tenantId: tenantA, schoolId: 'school_a', organizationId: 'org_a');
  const queryB = RepositoryQuery(tenantId: tenantB, schoolId: 'school_b', organizationId: 'org_b');

  setUp(() {
    TenantOnboardingStore.instance.reset(tenantA);
    TenantOnboardingStore.instance.reset(tenantB);
    StartupOnboardingProvisionStore.instance.reset(tenantA);
    StartupOnboardingProvisionStore.instance.reset(tenantB);
  });

  group('TenantOnboardingStore', () {
    test('persists onboarding across tenant scope', () {
      final store = TenantOnboardingStore.instance;
      store.save(
        tenantA,
        UnifiedOnboardingState.initial().copyWith(schoolName: 'NIKSHA Demo'),
      );
      store.save(
        tenantB,
        UnifiedOnboardingState.initial().copyWith(schoolName: 'Other School'),
      );

      expect(store.load(tenantA).schoolName, 'NIKSHA Demo');
      expect(store.load(tenantB).schoolName, 'Other School');
    });

    test('go live marks tenant as live when valid', () {
      final store = TenantOnboardingStore.instance;
      store.save(tenantA, _completeState());
      final live = store.goLive(tenantA);
      expect(live.isLive, isTrue);
      expect(live.currentStep, UnifiedOnboardingStep.goLive);
    });

    test('go live blocked when profile incomplete', () {
      final store = TenantOnboardingStore.instance;
      store.save(tenantA, UnifiedOnboardingState.initial());
      final blocked = store.goLive(tenantA);
      expect(blocked.isLive, isFalse);
      expect(blocked.goLiveValidationErrors, isNotEmpty);
    });
  });

  group('MockStartupOnboardingRepository', () {
    final repo = MockStartupOnboardingRepository();

    test('save onboarding state', () async {
      final saved = await repo.save(
        query: queryA,
        state: _completeState().copyWith(schoolName: 'Saved School'),
      );
      expect(saved.schoolName, 'Saved School');
      expect(saved.lastSavedAt, isNotNull);
    });

    test('restore onboarding state after save', () async {
      await repo.save(
        query: queryA,
        state: _completeState().copyWith(
          schoolName: 'Resume School',
          currentStep: UnifiedOnboardingStep.modules,
        ),
      );
      final restored = await repo.load(query: queryA);
      expect(restored.schoolName, 'Resume School');
      expect(restored.currentStep, UnifiedOnboardingStep.modules);
    });

    test('resume onboarding from saved step without restart', () async {
      await repo.save(
        query: queryA,
        state: _completeState().copyWith(
          currentStep: UnifiedOnboardingStep.language,
          schoolName: 'Step Four School',
        ),
      );
      final resumed = await repo.load(query: queryA);
      expect(resumed.currentStep, UnifiedOnboardingStep.language);
      expect(resumed.currentStep, isNot(UnifiedOnboardingStep.schoolProfile));
      expect(resumed.schoolName, 'Step Four School');
    });

    test('go live validation blocks incomplete schools', () async {
      await repo.save(query: queryA, state: UnifiedOnboardingState.initial());
      final result = await repo.goLive(query: queryA);
      expect(result.succeeded, isFalse);
      expect(result.validationErrors, isNotEmpty);
    });

    test('go live succeeds for complete configuration', () async {
      await repo.save(query: queryA, state: _completeState());
      final result = await repo.goLive(query: queryA);
      expect(result.succeeded, isTrue);
      expect(result.state.isLive, isTrue);
      expect(result.state.provisionSummary, isNotNull);
      expect(result.state.provisionSummary!.provisioned, isTrue);
      expect(result.state.provisionSummary!.classCount, greaterThan(0));
    });

    test('multi-admin consistency shares one tenant record', () async {
      await repo.save(
        query: queryA,
        state: _completeState().copyWith(schoolName: 'Admin One'),
      );
      final adminTwoView = await repo.load(query: queryA);
      expect(adminTwoView.schoolName, 'Admin One');

      await repo.save(
        query: queryA,
        state: adminTwoView.copyWith(
          schoolName: 'Admin Two Updated',
          currentStep: UnifiedOnboardingStep.review,
        ),
      );
      final adminOneView = await repo.load(query: queryA);
      expect(adminOneView.schoolName, 'Admin Two Updated');
      expect(adminOneView.currentStep, UnifiedOnboardingStep.review);
    });

    test('tenant isolation prevents cross-school bleed', () async {
      await repo.save(
        query: queryA,
        state: _completeState().copyWith(schoolName: 'School A'),
      );
      await repo.save(
        query: queryB,
        state: _completeState().copyWith(schoolName: 'School B'),
      );
      expect((await repo.load(query: queryA)).schoolName, 'School A');
      expect((await repo.load(query: queryB)).schoolName, 'School B');
    });
  });

  group('UnifiedOnboardingValidation', () {
    test('requires school profile academic fees language branding', () {
      final errors = UnifiedOnboardingValidation.validateForGoLive(
        UnifiedOnboardingState.initial().copyWith(feeModel: '', feeCategories: const []),
      );
      expect(errors, contains('School name is required'));
      expect(errors, contains('School address is required'));
      expect(errors, contains('Fee model is required'));
    });

    test('accepts complete state', () {
      final errors = UnifiedOnboardingValidation.validateForGoLive(_completeState());
      expect(errors, isEmpty);
    });
  });

  group('UnifiedOnboardingNotifier', () {
    test('hydrates from repository on build', () async {
      final repo = MockStartupOnboardingRepository();
      await repo.save(
        query: queryA,
        state: _completeState().copyWith(
          schoolName: 'Hydrated School',
          currentStep: UnifiedOnboardingStep.fees,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          startupOnboardingRepositoryProvider.overrideWithValue(repo),
          repositoryQueryProvider.overrideWithValue(queryA),
        ],
      );
      addTearDown(container.dispose);

      container.read(unifiedOnboardingProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(unifiedOnboardingProvider);
      expect(state.schoolName, 'Hydrated School');
      expect(state.currentStep, UnifiedOnboardingStep.fees);
      expect(state.isHydrated, isTrue);
    });
  });
}

UnifiedOnboardingState _completeState() {
  return UnifiedOnboardingState.initial().copyWith(
    schoolName: 'NIKSHA International',
    board: 'CBSE',
    curriculum: 'CBSE',
    address: '123 School Road',
    contactPhone: '9876543210',
    contactEmail: 'admin@akshara.edu',
    academicYear: '2026-27',
    classes: const ['Grade 1', 'Grade 2'],
    sections: const ['A', 'B'],
    feeModel: 'term_wise',
    feeCategories: const ['Tuition', 'Transport'],
    themePrimary: '#1565C0',
    themeSecondary: '#42A5F5',
    defaultLanguage: 'en',
  );
}
