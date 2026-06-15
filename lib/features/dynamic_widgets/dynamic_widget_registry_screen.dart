import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import '../evolution/evolution_models.dart';
import 'dynamic_widget_models.dart';
import 'dynamic_widget_providers.dart';

class DynamicWidgetRegistryScreen extends ConsumerWidget {
  const DynamicWidgetRegistryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registryState = ref.watch(dynamicWidgetRegistryProvider);
    final dataSourcesState = ref.watch(widgetDataSourcesProvider);
    final versionsState = ref.watch(
      widgetLayoutVersionsProvider((role: null, pack: 'school')),
    );

    return Scaffold(
      key: QaTestKeys.dynamicWidgetRegistryScreen,
      appBar: AppBar(
        title: const Text('Dynamic Widget Platform'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: QaTestKeys.dynamicWidgetOpenRuntimeButton,
                onPressed: () => context.push(RouteNames.dynamicWidgetRuntime),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Open runtime dashboard'),
              ),
              OutlinedButton.icon(
                key: QaTestKeys.dynamicWidgetOpenLayoutEditorButton,
                onPressed: () => context.push(RouteNames.dynamicWidgetLayout),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Edit layouts'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Widget catalog',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          registryState.when(
            loading: () => const AksharaLoadingState(),
            error: (error, _) =>
                AksharaErrorState(message: 'Unable to load catalog: $error'),
            data: (widgets) => _WidgetCatalogList(widgets: widgets),
          ),
          const SizedBox(height: 24),
          Text(
            'Data source bindings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          dataSourcesState.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('Data sources: $error'),
            data: (sources) => _DataSourceList(sources: sources),
          ),
          const SizedBox(height: 24),
          Text(
            'Layout versions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          versionsState.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('Versions: $error'),
            data: (versions) => _VersionList(versions: versions),
          ),
        ],
      ),
    );
  }
}

class _WidgetCatalogList extends StatelessWidget {
  const _WidgetCatalogList({required this.widgets});

  final List<WidgetDefinition> widgets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final widget in widgets)
          Card(
            key: QaTestKeys.dynamicWidgetCatalogItem(widget.id),
            child: ListTile(
              title: Text(widget.title),
              subtitle: Text(
                '${widget.category} · requires ${widget.requiredPermission}',
              ),
              trailing: Text('${widget.defaultWidth}×${widget.defaultHeight}'),
            ),
          ),
      ],
    );
  }
}

class _DataSourceList extends StatelessWidget {
  const _DataSourceList({required this.sources});

  final List<WidgetDataSource> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final source in sources)
          Card(
            key: QaTestKeys.dynamicWidgetDataSourceItem(source.key),
            child: ListTile(
              title: Text(source.label),
              subtitle: Text('${source.key} → ${source.repositoryModule}.${source.methodName}'),
              trailing: Text(
                source.supportedTypes.map((t) => t.name).join(', '),
              ),
            ),
          ),
      ],
    );
  }
}

class _VersionList extends StatelessWidget {
  const _VersionList({required this.versions});

  final List<WidgetLayoutVersion> versions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final version in versions)
          Card(
            key: QaTestKeys.dynamicWidgetLayoutVersion(version.role),
            child: ListTile(
              title: Text('${version.role} · v${version.version}'),
              subtitle: Text('${version.verticalPack} · ${version.layoutId}'),
              trailing: version.isTenantOverride
                  ? const Chip(label: Text('Custom'))
                  : const Chip(label: Text('Pack default')),
            ),
          ),
      ],
    );
  }
}
