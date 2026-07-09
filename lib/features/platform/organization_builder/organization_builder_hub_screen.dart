import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme_extensions.dart';
import 'organization_builder_models.dart';
import 'organization_builder_providers.dart';
import '../../../theme/spacing.dart';

/// Akshara is an education-only product — the salon/hospital/restaurant verticals
/// are explicitly out of scope (hide-first). The org-builder pack picker only
/// ever offers the school pack. The backend (`listPacks`) applies the same filter
/// as defense-in-depth; this is the user-facing gate.
const Set<VerticalPackType> _kSupportedVerticalPackTypes = {
  VerticalPackType.school,
};

class OrganizationBuilderHubScreen extends ConsumerWidget {
  const OrganizationBuilderHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsState = ref.watch(verticalPacksProvider);
    final draftsState = ref.watch(interviewDraftsProvider);

    return Scaffold(
      key: QaTestKeys.organizationBuilderHubScreen,
      appBar: AppBar(
        title: const Text('Organization Builder'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Card(
            key: QaTestKeys.schoolDiscoveryHubCard,
            child: ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Smart School Configuration'),
              subtitle: const Text(
                'FV-PLAT-14 — configure modules, curriculum, and operations model',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RouteNames.schoolDiscovery),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vertical Packs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          packsState.when(
            loading: () => const AksharaLoadingState(),
            error: (error, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(error),
              onRetry: () => ref.invalidate(verticalPacksProvider),
            ),
            data: (packs) => _PackGrid(
              packs: packs
                  .where((p) => _kSupportedVerticalPackTypes.contains(p.type))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Interview Drafts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          draftsState.when(
            loading: () => const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(error),
              onRetry: () => ref.invalidate(interviewDraftsProvider),
            ),
            data: (drafts) => _DraftList(drafts: drafts),
          ),
        ],
      ),
    );
  }
}

class _PackGrid extends StatelessWidget {
  const _PackGrid({required this.packs});

  final List<VerticalPack> packs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final pack in packs)
          SizedBox(
            width: 280,
            child: Card(
              key: QaTestKeys.organizationBuilderPackCard(pack.id),
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: context.aksharaText.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pack.description,
                      style: context.aksharaText.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Focus: ${pack.dashboardFocus}',
                      style: context.aksharaText.labelSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          key: QaTestKeys.organizationBuilderStartInterviewButton(
                            pack.id,
                          ),
                          onPressed: () {
                            final draftId =
                                'draft_${DateTime.now().microsecondsSinceEpoch}';
                            context.push(
                              '${RouteNames.organizationBuilderInterview}'
                              '?draftId=$draftId&packId=${pack.id}',
                            );
                          },
                          child: const Text('Start interview'),
                        ),
                        if (pack.type == VerticalPackType.school)
                          TextButton(
                            key: QaTestKeys.organizationBuilderSchoolSetupLink,
                            onPressed: () =>
                                context.push(RouteNames.setupWizard),
                            child: const Text('Setup wizard'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DraftList extends StatelessWidget {
  const _DraftList({required this.drafts});

  final List<InterviewDraft> drafts;

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) {
      return const Text('No interview drafts yet.');
    }

    return Column(
      children: [
        for (final draft in drafts)
          Card(
            key: QaTestKeys.organizationBuilderDraftRow(draft.id),
            child: ListTile(
              title: Text(draft.organizationName),
              subtitle: Text(
                'Step ${draft.currentStep}/7 · ${draft.status.value}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (draft.status == InterviewDraftStatus.readyForPreview) {
                  context.push(
                    '${RouteNames.organizationBuilderPreview}'
                    '?draftId=${draft.id}',
                  );
                } else {
                  context.push(
                    '${RouteNames.organizationBuilderInterview}'
                    '?draftId=${draft.id}&packId=${draft.packId}',
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}
