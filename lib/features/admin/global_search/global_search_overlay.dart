import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/school_config/school_configuration_models.dart';
import '../../../core/school_config/school_configuration_provider.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_motion.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'global_search_registry.dart';
import 'recent_routes_provider.dart';

/// Opens the global ERP search overlay.
Future<void> showGlobalSearchOverlay(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => AksharaMotionAppear(
      child: GlobalSearchOverlay(ref: ref),
    ),
  );
}

class GlobalSearchOverlay extends ConsumerStatefulWidget {
  const GlobalSearchOverlay({super.key, required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends ConsumerState<GlobalSearchOverlay> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _navigate(GlobalSearchEntry entry) {
    recordRecentRoute(widget.ref, entry.route);
    Navigator.of(context).pop();
    context.go(entry.route);
  }

  @override
  Widget build(BuildContext context) {
    final rbac = ref.watch(rbacServiceProvider);
    final capabilities = ref.watch(schoolCapabilitiesProvider);
    final recentRoutes = ref.watch(recentRoutesProvider);
    // RBAC filter: entries the user lacks the route's view-permission for must
    // neither surface nor be navigable (MJ-L8 / ADMIN-6). Capability filter:
    // entries whose optional module is disabled for the school are dropped so a
    // turned-off module never becomes a dead link (gap G6) — same source as nav.
    final recentEntries = GlobalSearchRegistry.entries
        .where((entry) => recentRoutes.contains(entry.route))
        .where((entry) => entry.isVisibleTo(rbac.hasPermission))
        .where((entry) => entry.isCapabilityEnabled(capabilities))
        .toList();
    final results = GlobalSearchRegistry.search(
      _query,
      hasPermission: rbac.hasPermission,
      capabilities: capabilities,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AksharaSpacing.s4,
                  AksharaSpacing.s4,
                  AksharaSpacing.s4,
                  AksharaSpacing.s2,
                ),
                child: TextField(
                  controller: _queryController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search modules, screens, workflows…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
                  children: [
                    if (_query.isEmpty && recentEntries.isNotEmpty) ...[
                      const _SectionHeader(title: 'Recent'),
                      for (final entry in recentEntries.take(5))
                        _SearchTile(entry: entry, onTap: () => _navigate(entry)),
                      const SizedBox(height: AksharaSpacing.s4),
                      const _SectionHeader(title: 'Quick actions'),
                      _QuickActionRow(
                        onNavigate: _navigate,
                        hasPermission: rbac.hasPermission,
                        capabilities: capabilities,
                      ),
                      const SizedBox(height: AksharaSpacing.s4),
                    ],
                    _SectionHeader(
                      title: _query.isEmpty ? 'All destinations' : 'Results',
                    ),
                    if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AksharaSpacing.s4),
                        child: Text('No matching screens.'),
                      )
                    else
                      for (final entry in results)
                        _SearchTile(entry: entry, onTap: () => _navigate(entry)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Text(
        title,
        style: context.aksharaText.titleSmall,
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({required this.entry, required this.onTap});

  final GlobalSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.arrow_outward),
      title: Text(entry.label),
      subtitle: Text(entry.module),
      onTap: onTap,
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onNavigate,
    required this.hasPermission,
    required this.capabilities,
  });

  final void Function(GlobalSearchEntry entry) onNavigate;
  final bool Function(Permission) hasPermission;
  final SchoolCapabilities capabilities;

  static const _quickIds = [
    RouteNames.admissionsEnrollment,
    RouteNames.financeDefaulters,
    RouteNames.sisStudents,
    RouteNames.managementIntelligence,
  ];

  @override
  Widget build(BuildContext context) {
    final quickEntries = GlobalSearchRegistry.entries
        .where((entry) => _quickIds.contains(entry.route))
        .where((entry) => entry.isVisibleTo(hasPermission))
        .where((entry) => entry.isCapabilityEnabled(capabilities))
        .toList();

    return Wrap(
      spacing: AksharaSpacing.s2,
      runSpacing: AksharaSpacing.s2,
      children: [
        for (final entry in quickEntries)
          ActionChip(
            label: Text(entry.label),
            onPressed: () => onNavigate(entry),
          ),
      ],
    );
  }
}
