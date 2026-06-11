import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import '../parent/parent_active_child_provider.dart';
import 'evolution_providers.dart';

/// Parent Insights Center — AI-generated insights only (no free chat).
class ParentInsightsScreen extends ConsumerWidget {
  const ParentInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(parentActiveStudentIdProvider);
    final insights = ref.watch(parentInsightsProvider(childId));
    final language = ref.watch(parentLanguagePreferenceProvider(childId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Insights'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (lang) async {
              await ref.read(evolutionRepositoryProvider).saveParentLanguagePreference(
                    query: ref.read(evolutionQueryProvider),
                    language: lang,
                    studentId: childId,
                  );
              ref.invalidate(parentLanguagePreferenceProvider(childId));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'english', child: Text('English')),
              PopupMenuItem(value: 'hindi', child: Text('Hindi')),
              PopupMenuItem(value: 'telugu', child: Text('Telugu')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: language.when(
                data: (l) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language),
                    const SizedBox(width: 4),
                    Text(l.toUpperCase()),
                  ],
                ),
                loading: () => const Icon(Icons.language),
                error: (_, __) => const Icon(Icons.language),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (period) async {
              final lang = await ref.read(evolutionRepositoryProvider).getParentLanguagePreference(
                    query: ref.read(evolutionQueryProvider),
                    studentId: childId,
                  );
              await ref.read(evolutionRepositoryProvider).generateParentInsights(
                    query: ref.read(evolutionQueryProvider),
                    studentId: childId,
                    period: period,
                    language: lang ?? 'english',
                  );
              ref.invalidate(parentInsightsProvider(childId));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'daily', child: Text('Generate daily')),
              PopupMenuItem(value: 'weekly', child: Text('Generate weekly')),
              PopupMenuItem(value: 'monthly', child: Text('Generate monthly')),
              PopupMenuItem(value: 'exam_prep', child: Text('Exam preparation')),
            ],
          ),
        ],
      ),
      body: insights.when(
        data: (items) => items.isEmpty
            ? AksharaEmptyState(
                message: 'No insights yet. Tap the menu to generate a summary.',
                actionLabel: 'Generate weekly',
                onAction: () async {
                  final lang = await ref.read(evolutionRepositoryProvider).getParentLanguagePreference(
                        query: ref.read(evolutionQueryProvider),
                        studentId: childId,
                      );
                  await ref.read(evolutionRepositoryProvider).generateParentInsights(
                        query: ref.read(evolutionQueryProvider),
                        studentId: childId,
                        period: 'weekly',
                        language: lang ?? 'english',
                      );
                  ref.invalidate(parentInsightsProvider(childId));
                },
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) => _insightCard(context, items[index]),
              ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading insights'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load parent insights.',
          onRetry: () => ref.invalidate(parentInsightsProvider(childId)),
        ),
      ),
    );
  }

  Widget _insightCard(BuildContext context, snapshot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${snapshot.period} · ${snapshot.language}', style: Theme.of(context).textTheme.titleMedium)),
                if (snapshot.printable)
                  IconButton(icon: const Icon(Icons.print_outlined), onPressed: () {}),
                if (snapshot.voiceReady) const Icon(Icons.record_voice_over_outlined, size: 20),
              ],
            ),
            Text(snapshot.progressSummary),
            const SizedBox(height: 8),
            _chips('Strengths', snapshot.strengths),
            _chips('Areas to improve', snapshot.weaknesses),
            _chips('Attendance', snapshot.attendanceInsights),
            _chips('Homework', snapshot.homeworkInsights),
            _chips('Suggestions', snapshot.improvementSuggestions),
            if (snapshot.teacherRemarksSummary.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Teacher remarks'),
                subtitle: Text(snapshot.teacherRemarksSummary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chips(String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Wrap(spacing: 8, children: items.map((i) => Chip(label: Text(i))).toList()),
        ],
      ),
    );
  }
}
