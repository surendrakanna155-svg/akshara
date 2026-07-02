import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../transport_workflow_actions.dart';
import '../widgets/transport_module_scaffold.dart';
import 'transport_stop_editor.dart';

/// TR-02 — Routes Management.
class TransportRoutesScreen extends ConsumerWidget {
  const TransportRoutesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Draft',
    'Inactive',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportRoutesLoadingProvider);
    final isError = ref.watch(transportRoutesErrorProvider);
    final isEmpty = ref.watch(transportRoutesEmptyProvider);
    final pageResult = ref.watch(transportRoutesPageResultProvider);
    final routes = ref.watch(transportFilteredRoutesProvider);
    final filterIndex = ref.watch(transportRoutesFilterProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.routes,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportRoutesFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AksharaManageAction(
              permission: Permission.manageTransport,
              child: FilledButton.icon(
                key: QaTestKeys.transportSaveRouteButton,
                onPressed: () => showCreateTransportRouteDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New route'),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _buildBody(
            context,
            ref: ref,
            isLoading: isLoading,
            isError: isError,
            isEmpty: isEmpty,
            routes: routes,
            pageResult: pageResult,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WidgetRef ref,
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<TransportRoute> routes,
    required PaginatedResult<TransportRoute>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading transport routes'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load transport routes.',
      );
    }

    if (isEmpty || routes.isEmpty) {
      return const AksharaEmptyState(
        message: 'No routes match the selected filters.',
        icon: Icons.route_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Route catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        _RoutesTable(routes: routes, ref: ref),
        if (pageResult != null)
          AksharaPaginationBar<TransportRoute>(
            result: pageResult,
            onPageChanged: (page) =>
                ref.read(transportRoutesPageProvider.notifier).state = page,
          ),
      ],
    );
  }
}

class _RoutesTable extends ConsumerWidget {
  const _RoutesTable({required this.routes, required this.ref});

  final List<TransportRoute> routes;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final route in routes) ...[
            _RouteCard(route: route, ref: this.ref),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('Route')),
        DataColumn(label: Text('Stops')),
        DataColumn(label: Text('Distance')),
        DataColumn(label: Text('AM')),
        DataColumn(label: Text('PM')),
        DataColumn(label: Text('Bus')),
        DataColumn(label: Text('Students')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Actions')),
      ],
      rowCount: routes.length,
      dataRowMinHeight: 56,
      semanticLabel: 'Routes table, ${routes.length} routes',
      rowBuilder: (index) {
        final route = routes[index];
        return DataRow(
          cells: [
            DataCell(Text(route.name)),
            DataCell(Text('${route.stopCount}')),
            DataCell(Text(route.distanceKm)),
            DataCell(Text(route.amDeparture)),
            DataCell(Text(route.pmDeparture)),
            DataCell(Text(route.assignedBus)),
            DataCell(Text('${route.studentCount}')),
            DataCell(_RouteStatusChip(status: route.status)),
            DataCell(
              AksharaManageAction(
                permission: Permission.manageTransport,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: QaTestKeys.transportEditStopsButton(route.id),
                      icon: const Icon(Icons.edit_road_outlined, size: 18),
                      tooltip: 'Edit stops',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showTransportStopEditor(
                        context,
                        this.ref,
                        route: route,
                      ),
                    ),
                    if (route.status == TransportRouteStatus.draft)
                      IconButton(
                        key: QaTestKeys.transportActivateRouteButton(route.id),
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        tooltip: 'Activate route',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showActivateTransportRouteDialog(
                          context,
                          this.ref,
                          route: route,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.route, required this.ref});

  final TransportRoute route;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Route ${route.name}, ${route.studentCount} students',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(route.name, style: text.titleSmall),
                  ),
                  _RouteStatusChip(status: route.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${route.stopCount} stops · ${route.distanceKm} · Bus ${route.assignedBus}',
                style: text.bodySmall,
              ),
              Text(
                'AM ${route.amDeparture} · PM ${route.pmDeparture} · ${route.studentCount} students',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Align(
                alignment: Alignment.centerRight,
                child: AksharaManageAction(
                  permission: Permission.manageTransport,
                  child: Wrap(
                    spacing: AksharaSpacing.s2,
                    children: [
                      TextButton(
                        key: QaTestKeys.transportEditStopsButton(route.id),
                        onPressed: () => showTransportStopEditor(
                          context,
                          ref,
                          route: route,
                        ),
                        child: const Text('Stops'),
                      ),
                      if (route.status == TransportRouteStatus.draft)
                        TextButton(
                          key: QaTestKeys.transportActivateRouteButton(route.id),
                          onPressed: () => showActivateTransportRouteDialog(
                            context,
                            ref,
                            route: route,
                          ),
                          child: const Text('Activate'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteStatusChip extends StatelessWidget {
  const _RouteStatusChip({required this.status});

  final TransportRouteStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      TransportRouteStatus.active => ('Active', KpiAccent.success),
      TransportRouteStatus.draft => ('Draft', KpiAccent.warning),
      TransportRouteStatus.inactive => ('Inactive', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
