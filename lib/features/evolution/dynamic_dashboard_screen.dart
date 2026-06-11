import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'evolution_models.dart';
import 'evolution_providers.dart';

class DynamicDashboardScreen extends ConsumerStatefulWidget {
  const DynamicDashboardScreen({super.key});

  @override
  ConsumerState<DynamicDashboardScreen> createState() => _DynamicDashboardScreenState();
}

class _DynamicDashboardScreenState extends ConsumerState<DynamicDashboardScreen> {
  List<DashboardWidgetPlacement>? _layout;

  @override
  Widget build(BuildContext context) {
    final widgets = ref.watch(widgetRegistryProvider);
    final layout = ref.watch(dashboardLayoutProvider);
    final liveData = ref.watch(widgetLiveDataProvider(false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(widgetLiveDataProvider(true)),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _layout == null
                ? null
                : () async {
                    await ref.read(evolutionRepositoryProvider).saveDashboardLayout(
                          query: ref.read(evolutionQueryProvider),
                          layout: _layout!,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dashboard layout saved')),
                    );
                  },
          ),
        ],
      ),
      body: widgets.when(
        data: (registry) => layout.when(
          data: (items) {
            final current = _layout ?? items;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Live widgets', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                liveData.when(
                  data: (data) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: current.where((p) => p.visible).map((placement) {
                      final live = data[placement.widgetId];
                      final title = registry
                          .firstWhere(
                            (w) => w.id == placement.widgetId,
                            orElse: () => WidgetDefinition(
                              id: placement.widgetId,
                              title: placement.widgetId,
                              category: 'general',
                              requiredPermission: 'viewAnalytics',
                            ),
                          )
                          .title;
                      if (live?.permissionDenied == true) {
                        return SizedBox(
                          width: 160,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('$title\nPermission required'),
                            ),
                          ),
                        );
                      }
                      return SizedBox(
                        width: 160,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: Theme.of(context).textTheme.labelLarge),
                                Text(
                                  live?.value ?? '—',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                Text(live?.summary ?? 'Loading…'),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Widget data: $e'),
                ),
                const SizedBox(height: 24),
                Text('Layout & visibility', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...List.generate(current.length, (index) {
                  final placement = current[index];
                  return Card(
                    child: SwitchListTile(
                      title: Text(
                        registry.firstWhere((w) => w.id == placement.widgetId, orElse: () => WidgetDefinition(
                              id: placement.widgetId,
                              title: placement.widgetId,
                              category: 'general',
                              requiredPermission: 'viewAnalytics',
                            )).title,
                      ),
                      subtitle: Text('Order ${placement.order + 1}'),
                      value: placement.visible,
                      onChanged: (v) {
                        setState(() {
                          _layout = current
                              .map((p) => p.widgetId == placement.widgetId ? p.copyWith(visible: v) : p)
                              .toList();
                        });
                        ref.invalidate(widgetLiveDataProvider(false));
                      },
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: index == 0
                                ? null
                                : () => _moveItem(current, index, index - 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: index >= current.length - 1
                                ? null
                                : () => _moveItem(current, index, index + 1),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading layout'),
          error: (e, _) => AksharaErrorState(message: '$e', onRetry: () => ref.invalidate(dashboardLayoutProvider)),
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading widgets'),
        error: (e, _) => AksharaErrorState(message: '$e', onRetry: () => ref.invalidate(widgetRegistryProvider)),
      ),
    );
  }

  void _moveItem(List<DashboardWidgetPlacement> current, int from, int to) {
    setState(() {
      final next = List<DashboardWidgetPlacement>.from(current);
      final item = next.removeAt(from);
      next.insert(to, item);
      _layout = [
        for (var i = 0; i < next.length; i++)
          DashboardWidgetPlacement(
            widgetId: next[i].widgetId,
            order: i,
            visible: next[i].visible,
            width: next[i].width,
            height: next[i].height,
          ),
      ];
    });
  }
}
