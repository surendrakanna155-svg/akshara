import 'package:akshara_erp/core/onboarding/startup_onboarding_provision_store.dart';
import 'package:akshara_erp/core/onboarding/tenant_onboarding_store.dart';
import 'package:akshara_erp/core/repositories/api/startup_onboarding/mapper/startup_onboarding_mapper.dart';
import 'package:akshara_erp/core/repositories/mock/mock_startup_onboarding_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/onboarding/ai_school_builder_models.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_models.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tenantA = 'tenant_ai';
  const queryA =
      RepositoryQuery(tenantId: tenantA, schoolId: 'school_ai', organizationId: 'org_ai');

  setUp(() {
    TenantOnboardingStore.instance.reset(tenantA);
    StartupOnboardingProvisionStore.instance.reset(tenantA);
  });

  group('SchoolBrief.toJson', () {
    test('drops empty values and keeps provided ones', () {
      final json = const SchoolBrief(
        schoolName: 'Akshara Public',
        board: 'CBSE',
        lowestGrade: '',
        estimatedStudents: 400,
        languages: ['Hindi'],
      ).toJson();
      expect(json['schoolName'], 'Akshara Public');
      expect(json['board'], 'CBSE');
      expect(json['estimatedStudents'], 400);
      expect(json['languages'], ['Hindi']);
      expect(json.containsKey('lowestGrade'), isFalse);
      expect(json.containsKey('contactPhone'), isFalse);
    });
  });

  group('SchoolBlueprintResult.fromJson', () {
    test('parses source, rationale and warnings', () {
      final meta = SchoolBlueprintResult.fromJson({
        'source': 'ai',
        'rationale': 'Tailored for CBSE.',
        'warnings': ['School name is missing'],
      });
      expect(meta.isAi, isTrue);
      expect(meta.rationale, 'Tailored for CBSE.');
      expect(meta.warnings, ['School name is missing']);
    });

    test('defaults to deterministic when fields missing', () {
      final meta = SchoolBlueprintResult.fromJson(const {});
      expect(meta.source, 'deterministic');
      expect(meta.isAi, isFalse);
      expect(meta.warnings, isEmpty);
    });
  });

  group('StartupOnboardingMapper.applyProposal', () {
    const mapper = StartupOnboardingMapper();

    test('applies non-empty proposal fields onto current state', () {
      final current = UnifiedOnboardingState.initial();
      final applied = mapper.applyProposal(current, {
        'classes': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5'],
        'sections': ['A', 'B', 'C'],
        'feeModel': 'quarterly',
        'feeCategories': ['Tuition', 'Lab'],
        'modulesEnabled': ['sis', 'finance', 'attendance', 'library'],
        'defaultLanguage': 'hi',
        'board': 'ICSE',
      });
      expect(applied.classes.length, 5);
      expect(applied.sections, ['A', 'B', 'C']);
      expect(applied.feeModel, 'quarterly');
      expect(applied.board, 'ICSE');
      expect(applied.modulesEnabled, contains('library'));
    });

    test('preserves current values for missing/empty proposal fields', () {
      final current = UnifiedOnboardingState.initial().copyWith(
        schoolName: 'Existing Name',
        feeModel: 'term_wise',
      );
      final applied = mapper.applyProposal(current, {
        'classes': ['Grade 6'],
        'feeModel': '',
      });
      expect(applied.schoolName, 'Existing Name');
      expect(applied.feeModel, 'term_wise');
      expect(applied.classes, ['Grade 6']);
    });
  });

  group('MockStartupOnboardingRepository.aiPrefill (offline draft)', () {
    final repo = MockStartupOnboardingRepository();

    test('builds classes from a grade range and section count', () async {
      final result = await repo.aiPrefill(
        query: queryA,
        current: UnifiedOnboardingState.initial(),
        brief: const SchoolBrief(
          schoolName: 'Offline School',
          board: 'CBSE',
          lowestGrade: 'Grade 1',
          highestGrade: 'Grade 5',
          sectionsPerGrade: 3,
        ),
      );
      expect(result.state.classes,
          ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5']);
      expect(result.state.sections, ['A', 'B', 'C']);
      expect(result.state.schoolName, 'Offline School');
      expect(result.meta.source, 'deterministic');
    });

    test('handles reversed range and loose labels', () async {
      final result = await repo.aiPrefill(
        query: queryA,
        current: UnifiedOnboardingState.initial(),
        brief: const SchoolBrief(lowestGrade: '10', highestGrade: 'class 6'),
      );
      expect(result.state.classes,
          ['Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10']);
    });
  });

  group('UnifiedOnboardingNotifier.aiPrefill', () {
    test('applies the proposal and persists it', () async {
      final repo = MockStartupOnboardingRepository();
      final container = ProviderContainer(
        overrides: [
          startupOnboardingRepositoryProvider.overrideWithValue(repo),
          repositoryQueryProvider.overrideWithValue(queryA),
        ],
      );
      addTearDown(container.dispose);

      container.read(unifiedOnboardingProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final meta = await container.read(unifiedOnboardingProvider.notifier).aiPrefill(
            const SchoolBrief(
              schoolName: 'Wired School',
              board: 'CBSE',
              lowestGrade: 'Grade 1',
              highestGrade: 'Grade 3',
            ),
          );

      final state = container.read(unifiedOnboardingProvider);
      expect(state.schoolName, 'Wired School');
      expect(state.classes, ['Grade 1', 'Grade 2', 'Grade 3']);
      expect(state.isLoading, isFalse);
      expect(meta.source, 'deterministic');

      // Persisted: a fresh load returns the applied draft.
      final reloaded = await repo.load(query: queryA);
      expect(reloaded.schoolName, 'Wired School');
      expect(reloaded.classes, ['Grade 1', 'Grade 2', 'Grade 3']);
    });
  });
}
