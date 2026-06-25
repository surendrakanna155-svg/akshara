import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../features/school_completion/school_branding_theme_provider.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/premium_tokens.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../parent/parent_active_child_provider.dart';
import 'evolution_models.dart';
import 'evolution_providers.dart';
import 'parent_insights_pdf_service.dart';

/// Parent Insights Center — AI-generated progress summaries (no free chat).
///
/// B3: surfaced for parents on the live backend. Premium "School OS" styling,
/// real PDF print/share, in-progress generation feedback, multilingual.
class ParentInsightsScreen extends ConsumerStatefulWidget {
  const ParentInsightsScreen({super.key});

  @override
  ConsumerState<ParentInsightsScreen> createState() =>
      _ParentInsightsScreenState();
}

class _ParentInsightsScreenState extends ConsumerState<ParentInsightsScreen> {
  static const _pdfService = ParentInsightsPdfService();

  bool _generating = false;

  static const _periodLabels = <String, String>{
    'daily': 'Daily',
    'weekly': 'Weekly',
    'monthly': 'Monthly',
    'exam_prep': 'Exam prep',
  };

  static const _languageLabels = <String, String>{
    'english': 'English',
    'hindi': 'Hindi',
    'telugu': 'Telugu',
  };

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(parentActiveStudentIdProvider);
    final activeChild = ref.watch(parentActiveChildProvider);
    final insights = ref.watch(parentInsightsProvider(childId));
    final language = ref.watch(parentLanguagePreferenceProvider(childId));
    final childName = activeChild?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Insights'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Insight language',
            onSelected: (lang) => _setLanguage(childId, lang),
            itemBuilder: (_) => [
              for (final entry in _languageLabels.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: language.when(
                data: (l) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language),
                    const SizedBox(width: 4),
                    Text((_languageLabels[l] ?? l).toUpperCase()),
                  ],
                ),
                loading: () => const Icon(Icons.language),
                error: (_, __) => const Icon(Icons.language),
              ),
            ),
          ),
        ],
      ),
      body: AksharaPremiumBackground(
        motif: AksharaMotif.spark,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AksharaGradientHero(
                      eyebrow: 'PARENT INSIGHTS',
                      headline: childName.isEmpty
                          ? 'AI summaries of your child\'s progress'
                          : '$childName\'s progress, summarised',
                      motif: AksharaMotif.spark,
                      pills: [
                        language.maybeWhen(
                          data: (l) => AksharaHeroPill(
                            label: _languageLabels[l] ?? l,
                            tone: KpiAccent.primary,
                          ),
                          orElse: () => const AksharaHeroPill(
                            label: 'English',
                            tone: KpiAccent.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AksharaSpacing.s4),
                    _GenerateCard(
                      generating: _generating,
                      periodLabels: _periodLabels,
                      onGenerate: (period) => _generate(childId, period),
                    ),
                    const SizedBox(height: AksharaSpacing.s4),
                    insights.when(
                      data: (items) => items.isEmpty
                          ? _emptyState(childId)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const AksharaSectionHeader(
                                  title: 'Recent summaries',
                                ),
                                const SizedBox(height: AksharaSpacing.s3),
                                for (final item in items) ...[
                                  _PremiumInsightCard(
                                    snapshot: item,
                                    periodLabel: _periodLabels[item.period] ??
                                        item.period,
                                    languageLabel:
                                        _languageLabels[item.language] ??
                                            item.language,
                                    onPrint: () => _printInsight(item),
                                  ),
                                  const SizedBox(height: AksharaSpacing.s3),
                                ],
                              ],
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: AksharaSpacing.s6),
                        child: AksharaLoadingState(
                          semanticLabel: 'Loading insights',
                        ),
                      ),
                      error: (e, _) => AksharaSectionError(
                        message: 'Unable to load parent insights.',
                        onRetry: () =>
                            ref.invalidate(parentInsightsProvider(childId)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(String childId) {
    return AksharaPremiumEmptyState(
      motif: AksharaMotif.spark,
      title: 'No insights yet',
      message:
          'Generate an AI summary of your child\'s recent attendance, homework '
          'and progress — in your preferred language.',
      actionLabel: _generating ? null : 'Generate weekly',
      onAction: _generating ? null : () => _generate(childId, 'weekly'),
    );
  }

  Future<void> _setLanguage(String childId, String lang) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(evolutionRepositoryProvider).saveParentLanguagePreference(
          query: ref.read(evolutionQueryProvider),
          language: lang,
          studentId: childId,
        );
    ref.invalidate(parentLanguagePreferenceProvider(childId));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Language set to ${_languageLabels[lang] ?? lang}. New summaries will '
          'use it.',
        ),
      ),
    );
  }

  Future<void> _generate(String childId, String period) async {
    if (_generating) return;
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final lang = await ref
          .read(evolutionRepositoryProvider)
          .getParentLanguagePreference(
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
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('${_periodLabels[period] ?? period} insight generated.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not generate insight. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _printInsight(ParentInsightSnapshot snapshot) async {
    final messenger = ScaffoldMessenger.of(context);
    final child = ref.read(parentActiveChildProvider);
    final schoolName = ref.read(schoolDisplayNameProvider);
    try {
      final bytes = await _pdfService.buildInsightPdf(
        snapshot,
        schoolName: schoolName,
        childName: child?.name ?? 'Student',
        childClass: child?.classLabel ?? '',
      );
      await _pdfService.printInsight(bytes);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the insight document.')),
      );
    }
  }
}

/// Premium "generate a new summary" card with period choices + progress.
class _GenerateCard extends StatelessWidget {
  const _GenerateCard({
    required this.generating,
    required this.periodLabels,
    required this.onGenerate,
  });

  final bool generating;
  final Map<String, String> periodLabels;
  final void Function(String period) onGenerate;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final premium = context.premium;

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: premium.brandStart),
              const SizedBox(width: AksharaSpacing.s2),
              Text(
                'Generate a new summary',
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          if (generating)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Text(
                  'Generating insight…',
                  style: text.bodyMedium
                      .copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            )
          else
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final entry in periodLabels.entries)
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(entry.value),
                    onPressed: () => onGenerate(entry.key),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Premium insight card with sectioned, accent-coded content.
class _PremiumInsightCard extends StatelessWidget {
  const _PremiumInsightCard({
    required this.snapshot,
    required this.periodLabel,
    required this.languageLabel,
    required this.onPrint,
  });

  final ParentInsightSnapshot snapshot;
  final String periodLabel;
  final String languageLabel;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AksharaStatusChip(
                      label: periodLabel,
                      tone: KpiAccent.primary,
                    ),
                    AksharaStatusChip(
                      label: languageLabel,
                      tone: KpiAccent.neutral,
                    ),
                  ],
                ),
              ),
              if (snapshot.printable)
                IconButton(
                  tooltip: 'Print / share',
                  icon: const Icon(Icons.ios_share_outlined),
                  onPressed: onPrint,
                ),
            ],
          ),
          if (snapshot.progressSummary.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s3),
            Text(snapshot.progressSummary, style: text.bodyMedium),
          ],
          _section(context, 'Strengths', snapshot.strengths,
              KpiAccent.success, Icons.trending_up),
          _section(context, 'Areas to improve', snapshot.weaknesses,
              KpiAccent.warning, Icons.flag_outlined),
          _section(context, 'Attendance', snapshot.attendanceInsights,
              KpiAccent.primary, Icons.event_available_outlined),
          _section(context, 'Homework', snapshot.homeworkInsights,
              KpiAccent.indigo, Icons.assignment_outlined),
          _section(context, 'Suggestions', snapshot.improvementSuggestions,
              KpiAccent.tertiary, Icons.lightbulb_outline),
          if (snapshot.teacherRemarksSummary.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s3),
            Container(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AksharaRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher remarks',
                    style:
                        text.labelMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(snapshot.teacherRemarksSummary, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String label,
    List<String> items,
    KpiAccent accent,
    IconData icon,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Padding(
      padding: const EdgeInsets.only(top: AksharaSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColors.foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: text.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColors.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(item, style: text.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
