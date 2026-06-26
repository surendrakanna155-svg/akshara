import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../theme/spacing.dart';

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
            templates.when(
              loading: () => const AksharaLoadingState(),
              error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
              data: (items) => ListView.builder(
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
            chapters.when(
              loading: () => const AksharaLoadingState(),
              error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
              data: (items) => Column(
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
                      error: (_, __) => const SizedBox.shrink(),
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
            catalog.when(
              loading: () => const AksharaLoadingState(),
              error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
              data: (data) {
                if (data.years.length < 2) {
                  return const AksharaEmptyState(
                    message: 'Add at least two academic years to clone syllabus.',
                  );
                }
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
