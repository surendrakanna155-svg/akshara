import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/erp_role.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/parent/parent_active_child_provider.dart';
import '../../router/route_names.dart';
import 'copilot_role_intelligence.dart';
import 'copilot_screen_context.dart';

/// Optional screen-level overrides (KPIs, filters, records) from feature widgets.
final copilotScreenOverrideProvider =
    StateProvider<CopilotScreenContext?>((ref) => null);

/// Context captured when navigating from another ERP screen into copilot.
final copilotPendingNavigationContextProvider =
    StateProvider<CopilotScreenContext?>((ref) => null);

/// Builds the effective copilot context from auth, route, and overrides.
final copilotEffectiveContextProvider = Provider<CopilotScreenContext?>((ref) {
  final pending = ref.watch(copilotPendingNavigationContextProvider);
  if (pending != null) return pending;

  final override = ref.watch(copilotScreenOverrideProvider);
  if (override != null) return override;

  final auth = ref.watch(authProvider);
  final claims = auth.claims;
  if (claims == null) return null;

  final tenant = ref.watch(tenantContextProvider);
  final persona = copilotPersonaForErpRole(claims.erpRole);
  final activeChildId = claims.erpRole == ErpRole.parent
      ? ref.watch(parentActiveStudentIdProvider)
      : null;

  return CopilotScreenContext(
    personaRole: persona,
    erpRole: claims.erpRole,
    schoolId: claims.schoolId ?? tenant.schoolId ?? '',
    organizationId: claims.organizationId ?? tenant.organizationId ?? '',
    tenantId: claims.tenantId,
    schoolName: null,
    module: 'copilot',
    route: RouteNames.copilot,
    screen: 'AI Copilot',
    suggestedAssistant: defaultAssistantForPersona(persona),
    activeChildId: activeChildId,
  );
});

CopilotScreenContext buildCopilotScreenContext(
  WidgetRef ref, {
  required String originRoute,
  Map<String, String>? filters,
  List<CopilotKpiSnapshot>? kpis,
  Map<String, String>? records,
  String? screen,
}) {
  final auth = ref.read(authProvider);
  final claims = auth.claims;
  final tenant = ref.read(tenantContextProvider);
  if (claims == null) {
    return CopilotScreenContext(
      personaRole: CopilotPersonaRole.directorCorrespondent,
      erpRole: ErpRole.management,
      schoolId: tenant.schoolId ?? '',
      organizationId: tenant.organizationId ?? '',
      tenantId: tenant.tenantId,
      schoolName: null,
      module: copilotModuleForRoute(originRoute),
      route: originRoute,
      screen: screen ?? copilotScreenLabelForRoute(originRoute),
      originRoute: originRoute,
      filters: filters ?? const {},
      kpis: kpis ?? const [],
      records: records ?? const {},
    );
  }

  final persona = copilotPersonaForErpRole(claims.erpRole);
  final activeChildId = claims.erpRole == ErpRole.parent
      ? ref.read(parentActiveStudentIdProvider)
      : null;

  return CopilotScreenContext(
    personaRole: persona,
    erpRole: claims.erpRole,
    schoolId: claims.schoolId ?? tenant.schoolId ?? '',
    organizationId: claims.organizationId ?? tenant.organizationId ?? '',
    tenantId: claims.tenantId,
    schoolName: null,
    module: copilotModuleForRoute(originRoute),
    route: originRoute,
    screen: screen ?? copilotScreenLabelForRoute(originRoute),
    originRoute: originRoute,
    filters: filters ?? const {},
    kpis: kpis ?? const [],
    records: records ?? const {},
    activeChildId: activeChildId,
    suggestedAssistant: assistantForRoute(originRoute, persona),
  );
}

/// Publishes KPI/filter/record context for the current screen.
class CopilotContextScope extends ConsumerStatefulWidget {
  const CopilotContextScope({
    super.key,
    required this.child,
    this.screen,
    this.module,
    this.route,
    this.filters = const {},
    this.kpis = const [],
    this.records = const {},
  });

  final Widget child;
  final String? screen;
  final String? module;
  final String? route;
  final Map<String, String> filters;
  final List<CopilotKpiSnapshot> kpis;
  final Map<String, String> records;

  @override
  ConsumerState<CopilotContextScope> createState() => _CopilotContextScopeState();
}

class _CopilotContextScopeState extends ConsumerState<CopilotContextScope> {
  @override
  void didUpdateWidget(covariant CopilotContextScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  void _publish() {
    final route = widget.route ?? _resolveRoute(context);
    final base = buildCopilotScreenContext(
      ref,
      originRoute: route,
      screen: widget.screen,
      filters: widget.filters,
      kpis: widget.kpis,
      records: widget.records,
    );
    ref.read(copilotScreenOverrideProvider.notifier).state = base.copyWith(
      module: widget.module ?? base.module,
      screen: widget.screen ?? base.screen,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _resolveRoute(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    return '/';
  }
}
