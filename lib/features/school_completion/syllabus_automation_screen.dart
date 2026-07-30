import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_text.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/async/erp_async_state.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// v12.7 — Subject templates, auto generation, and year cloning.
class SyllabusAutomationScreen extends ConsumerStatefulWidget {
  const SyllabusAutomationScreen({super.key});

  @override
  ConsumerState<SyllabusAutomationScreen> createState() =>
      _SyllabusAutomationScreenState();
}

class _SyllabusAutomationScreenState extends ConsumerState<SyllabusAutomationScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(subjectTemplatesProvider);
    final chapters = ref.watch(syllabusChaptersProvider(null));
    final catalog = ref.watch(academicCatalogFutureProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Syllabus Automation'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Templates'),
              Tab(text: 'Generated'),
              Tab(text: 'Clone year'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ErpAsyncBody(
              state: resolveErpAsync(templates, isDataEmpty: (_) => false),
              loadingLabel: 'Loading',
              emptyMessage: 'No subject templates available.',
              onRetry: () => ref.invalidate(subjectTemplatesProvider),
              builder: (items) => ListView.builder(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final tpl = items[index];
                  return ExpansionTile(
                    title: Text('${tpl.subjectName} (${tpl.board})'),
                    subtitle: Text('${tpl.gradeLabel} · ${tpl.chapters.length} chapters'),
                    children: [
                      for (final ch in tpl.chapters)
                        ListTile(
                          dense: true,
                          title: Text(ch.name),
                          subtitle: Text(ch.topics.join(', ')),
                        ),
                    ],
                  );
                },
              ),
            ),
            ErpAsyncBody(
              state: resolveErpAsync(chapters, isDataEmpty: (_) => false),
              loadingLabel: 'Loading',
              emptyMessage: 'No syllabus chapters available.',
              onRetry: () => ref.invalidate(syllabusChaptersProvider(null)),
              builder: (items) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AksharaSpacing.s4),
                    child: catalog.when(
                      data: (data) {
                        final yearId =
                            data.years.isNotEmpty ? data.years.first.yearId : 'year_1';
                        return FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _generate(context, yearId: yearId),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Auto-generate syllabus'),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      // The action used to disappear entirely when the academic
                      // catalog failed to load, leaving the user staring at a
                      // screen with no button and no reason for its absence —
                      // indistinguishable from the feature not existing. Keep
                      // the affordance visible but disabled, and say why.
                      error: (error, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Auto-generate syllabus'),
                          ),
                          const SizedBox(height: AksharaSpacing.s2),
                          Text(
                            "Can't generate right now — the academic year "
                            'could not be loaded. ${aksharaErrorMessage(error)}',
                            style: context.aksharaText.bodySmall
                                .copyWith(color: context.colors.error),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(academicCatalogFutureProvider),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final ch = items[index];
                        return ListTile(
                          title: Text(ch.chapterName),
                          subtitle: Text('${ch.className} · ${ch.status}'),
                          trailing: Text('#${ch.sequenceOrder}'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            ErpAsyncBody(
              state: resolveErpAsync(
                catalog,
                isDataEmpty: (data) => data.years.length < 2,
              ),
              loadingLabel: 'Loading',
              emptyMessage: 'Add at least two academic years to clone syllabus.',
              onRetry: () => ref.invalidate(academicCatalogFutureProvider),
              builder: (data) {
                final from = data.years.first.yearId;
                final to = data.years[1].yearId;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AksharaSpacing.s6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Clone from ${data.years.first.yearLabel} → ${data.years[1].yearLabel}'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _clone(context, from: from, to: to),
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Clone syllabus'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, {required String yearId}) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(schoolCompletionRepositoryProvider);
      final query = ref.read(schoolCompletionQueryProvider);
      final result = await repo.generateSyllabus(
        query: query,
        academicYearId: yearId,
        className: 'Grade 7',
        subjectId: 'sub_1',
        subjectName: 'Mathematics',
        gradeLabel: 'Grade 7',
      );
      ref.invalidate(syllabusChaptersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created ${result.chaptersCreated} chapters, ${result.topicsCreated} topics',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clone(
    BuildContext context, {
    required String from,
    required String to,
  }) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(schoolCompletionRepositoryProvider);
      final query = ref.read(schoolCompletionQueryProvider);
      final result = await repo.cloneSyllabus(
        query: query,
        fromYearId: from,
        toYearId: to,
      );
      ref.invalidate(syllabusChaptersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloned ${result.chaptersCreated} chapters')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
