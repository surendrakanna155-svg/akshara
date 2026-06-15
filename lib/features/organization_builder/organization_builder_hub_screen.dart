import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import 'organization_builder_models.dart';
import 'organization_builder_providers.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Vertical Packs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          packsState.when(
            loading: () => const AksharaLoadingState(),
            error: (error, _) =>
                AksharaErrorState(message: 'Unable to load packs: $error'),
            data: (packs) => _PackGrid(packs: packs),
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
            error: (error, _) => Text('Unable to load drafts: $error'),
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pack.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Focus: ${pack.dashboardFocus}',
                      style: Theme.of(context).textTheme.labelSmall,
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
