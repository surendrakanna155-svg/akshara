import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/rbac_service.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'dynamic_widget_models.dart';
import 'dynamic_widget_providers.dart';

class DynamicWidgetRuntimeScreen extends ConsumerWidget {
  const DynamicWidgetRuntimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(dynamicWidgetRoleProvider);
    final layoutState = ref.watch(roleDashboardLayoutProvider(role));
    final liveDataState = ref.watch(dynamicWidgetLiveDataProvider(role));
    final rbac = ref.watch(rbacServiceProvider);

    return Scaffold(
      key: QaTestKeys.dynamicWidgetRuntimeScreen,
      appBar: AppBar(
        title: const Text('Dynamic Dashboard'),
        actions: [
          IconButton(
            key: QaTestKeys.dynamicWidgetRuntimeRefreshButton,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dynamicWidgetLiveDataProvider(role)),
          ),
        ],
      ),
      body: layoutState.when(
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading dashboard'),
        error: (error, _) => AksharaErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(roleDashboardLayoutProvider(role)),
        ),
        data: (layout) {
          final widgets = filterWidgetsByRbac(layout.widgets, rbac);
          return liveDataState.when(
            loading: () => const AksharaLoadingState(semanticLabel: 'Loading widget data'),
            error: (error, _) => AksharaErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(dynamicWidgetLiveDataProvider(role)),
            ),
            data: (liveData) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Role: $role · v${layout.version}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (layout.navigation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final nav in layout.navigation)
                        ActionChip(
                          label: Text(nav.label),
                          onPressed: () => context.push(nav.route),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final widget in widgets)
                          SizedBox(
                            width: _tileWidth(constraints.maxWidth, widget.size),
                            child: _DynamicWidgetTile(
                              widget: widget,
                              liveData: liveData[widget.id],
                              onTap: widget.drillDown == null
                                  ? null
                                  : () => context.push(widget.drillDown!),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (widgets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No widgets visible for your permissions.')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _tileWidth(double maxWidth, WidgetGridSize size) {
    if (maxWidth < 600) return maxWidth;
    final fraction = size.flex / 12;
    return (maxWidth * fraction) - 12;
  }
}

class _DynamicWidgetTile extends StatelessWidget {
  const _DynamicWidgetTile({
    required this.widget,
    required this.liveData,
    this.onTap,
  });

  final DynamicWidgetItem widget;
  final dynamic liveData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final denied = liveData?.permissionDenied == true;

    return Card(
      key: QaTestKeys.dynamicWidgetRuntimeTile(widget.id),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeIcon(type: widget.type),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (widget.drillDown != null)
                    Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              if (denied)
                Text(
                  'Permission required',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else ...[
                Text(
                  liveData?.value?.toString() ?? '—',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  liveData?.summary?.toString() ?? widget.type.name,
                  style: theme.textTheme.bodySmall,
                ),
                if (liveData?.alerts is List && (liveData!.alerts as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final alert in liveData!.alerts as List)
                    Text('• $alert', style: theme.textTheme.labelSmall),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final WidgetType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      WidgetType.kpi => Icons.speed_outlined,
      WidgetType.chart => Icons.bar_chart_outlined,
      WidgetType.list => Icons.list_alt_outlined,
      WidgetType.alert => Icons.warning_amber_outlined,
      WidgetType.action => Icons.touch_app_outlined,
    };
    return Icon(icon, size: 20);
  }
}
