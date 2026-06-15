import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'resource_optimization_models.dart';
import 'resource_optimization_mutations_provider.dart';
import 'resource_optimization_providers.dart';

class ResourceOptimizationScreen extends ConsumerStatefulWidget {
  const ResourceOptimizationScreen({super.key});

  @override
  ConsumerState<ResourceOptimizationScreen> createState() =>
      _ResourceOptimizationScreenState();
}

class _ResourceOptimizationScreenState
    extends ConsumerState<ResourceOptimizationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _domains = ResourceOptimizationDomain.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _domains.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applying = ref.watch(applyResourceOptimizationRecommendationProvider);
    final dismissing =
        ref.watch(dismissResourceOptimizationRecommendationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Optimization Engine'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final domain in _domains)
              Tab(
                key: QaTestKeys.resourceOptimizationTab(domain.name),
                text: domain.label,
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final domain in _domains)
            _DomainRecommendationsList(
              domain: domain,
              applying: applying.isLoading,
              dismissing: dismissing.isLoading,
            ),
        ],
      ),
    );
  }
}

class _DomainRecommendationsList extends ConsumerWidget {
  const _DomainRecommendationsList({
    required this.domain,
    required this.applying,
    required this.dismissing,
  });

  final ResourceOptimizationDomain domain;
  final bool applying;
  final bool dismissing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(resourceOptimizationRecommendationsProvider(domain));
    return state.when(
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState(
        message: 'Unable to load recommendations',
        onRetry: () =>
            ref.invalidate(resourceOptimizationRecommendationsProvider(domain)),
      ),
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const AksharaEmptyState(
            message: 'No recommendations right now for this domain.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: recommendations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final recommendation = recommendations[index];
            return Card(
              child: ListTile(
                title: Text(recommendation.title),
                subtitle: Text(
                  '${recommendation.summary}\n'
                  'Impact: ${recommendation.expectedImpact}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (recommendation.applied)
                      const Chip(label: Text('Applied')),
                    if (recommendation.dismissed)
                      const Chip(label: Text('Dismissed')),
                    IconButton(
                      key: QaTestKeys.resourceOptimizationApplyButton(
                        recommendation.id,
                      ),
                      tooltip: 'Apply recommendation',
                      onPressed: applying
                          ? null
                          : () => _apply(
                                context,
                                ref,
                                domain: domain,
                                recommendationId: recommendation.id,
                              ),
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                    IconButton(
                      key: QaTestKeys.resourceOptimizationDismissButton(
                        recommendation.id,
                      ),
                      tooltip: 'Dismiss recommendation',
                      onPressed: dismissing
                          ? null
                          : () => _dismiss(
                                context,
                                ref,
                                domain: domain,
                                recommendationId: recommendation.id,
                              ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref, {
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    final result = await ref
        .read(applyResourceOptimizationRecommendationProvider.notifier)
        .execute(domain: domain, recommendationId: recommendationId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.resourceOptimizationAppliedSnackbar,
        content: Text('Optimization recommendation applied.'),
      ),
    );
  }

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref, {
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    final result = await ref
        .read(dismissResourceOptimizationRecommendationProvider.notifier)
        .execute(domain: domain, recommendationId: recommendationId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.resourceOptimizationDismissedSnackbar,
        content: Text('Optimization recommendation dismissed.'),
      ),
    );
  }
}
