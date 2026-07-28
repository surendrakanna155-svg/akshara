import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dai/dai_intent.dart';
import '../../../core/dai/dai_resolver.dart';
import '../../../core/school_config/school_configuration_models.dart';
import '../../../core/school_config/school_configuration_provider.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_motion.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../adaptive_ai/adaptive_ai_models.dart';
import '../../adaptive_ai/adaptive_ai_providers.dart';
import '../../adaptive_ai/widgets/adaptive_search_results.dart';
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

  /// Open an Adaptive Universal Search record (student/staff/lead) — deterministic
  /// navigation to the ERP record, no AI call (Search First → AI Later).
  void _openRecord(SearchResultItem item) {
    // Pass the caller's RBAC so a student result opens the Student 360 dossier
    // for roles that hold viewStudent360 (principal, VP, admin, management,
    // teacher) and falls back to the SIS detail page for everyone else, instead
    // of routing them into Access Denied.
    final route = adaptiveSearchRoute(
      item.category,
      item.id,
      hasPermission: ref.read(rbacServiceProvider).hasPermission,
    );
    if (route == null) return;
    Navigator.of(context).pop();
    context.go(route);
  }

  /// The DAI intent for the current query, or null when the resolver is not
  /// confident, when it needs a directory lookup (the entity list below already
  /// answers that better), or when this user lacks the destination's permission.
  ///
  /// Permission is checked HERE, not in the resolver: the DAI layer resolves
  /// meaning and deliberately knows nothing about who is asking.
  DaiIntent? _resolveDai(bool Function(Permission) hasPermission) {
    if (_query.length < 3) return null;
    final intent = DaiResolver.resolve(_query);
    if (!intent.isResolved) return null;
    if (intent.needsDirectoryLookup || intent.route == null) return null;
    final permission = intent.requiredPermission;
    if (permission != null && !hasPermission(permission)) return null;
    return intent;
  }

  DaiIntent? _daiAnswer;

  @override
  Widget build(BuildContext context) {
    final rbac = ref.watch(rbacServiceProvider);
    _daiAnswer = _resolveDai(rbac.hasPermission);
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
                    // The hint teaches the DAI vocabulary. Users do not discover
                    // that they can type "fee defaulters" unless shown.
                    hintText: 'Ask anything — "fee defaulters", "Class 8A"…',
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
                    // DAI — the deterministic intent answer, on top. Resolved
                    // on-device with no network call and no tokens, so it lands
                    // instantly and works offline. Only shown when the resolver
                    // is confident AND the destination is one this user may open.
                    if (_daiAnswer != null)
                      _DaiAnswerCard(
                        intent: _daiAnswer!,
                        onGo: () {
                          Navigator.of(context).pop();
                          context.go(_daiAnswer!.route!);
                        },
                      ),
                    // W2.S — deterministic, RBAC-scoped entity records (students /
                    // staff / admissions). Self-hides for short/empty queries.
                    AdaptiveSearchResults(query: _query, onSelect: _openRecord),
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

/// The DAI answer card — what makes global search feel like an operating
/// system rather than a filter box.
///
/// Deliberately styled as an *answer*, not a result row: the sentence comes
/// first, the destination second. Every word of it was composed deterministically
/// by [DaiResolver] from the user's own query, so it can never say something the
/// system will not then do.
class _DaiAnswerCard extends StatelessWidget {
  const _DaiAnswerCard({required this.intent, required this.onGo});

  final DaiIntent intent;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          onTap: onGo,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: colors.primary),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Text(
                    intent.answer,
                    style: text.bodyMedium.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 18, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
