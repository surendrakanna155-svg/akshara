import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/entitlements/entitlement_models.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/repositories/repository_config.dart';
import '../../core/school_config/school_capability_registry.dart';
import '../../core/widgets/whatsapp_contact_button.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/akshara_surface_card.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/models/admin_nav_models.dart';
import 'plan_entitlements_screen.dart' show kAksharaSalesWhatsApp;

/// Whether a module is locked by the org's plan ceiling (B2). False when the
/// entitlement layer is disabled (unrestricted ceiling) — pre-B2 behaviour.
final modulePlanLockedProvider = Provider.family<bool, AdminModule>((ref, module) {
  // Marketing is gated by `module.marketing` — a plan entitlement that is NOT one
  // of the 8 SchoolCapabilities flags, so it resolves from the entitlement set
  // directly (mirrors the server `withEntitlement("/growth", "module.marketing")`).
  if (module == AdminModule.marketing) {
    if (!ref.watch(entitlementApiEnabledProvider)) return false;
    return !ref.watch(subscriptionProvider).allows(EntitlementSlugs.marketing);
  }
  final ceiling = ref.watch(planCapabilityCeilingProvider);
  return !SchoolCapabilityRegistry.isAdminModuleEnabled(module, ceiling);
});

/// Wraps a module screen: renders the locked/upgrade view when the module is
/// plan-locked, otherwise the real [child]. Defense-in-depth on the client — the
/// server also returns 402 when enforcement is on.
class EntitlementModuleGate extends ConsumerWidget {
  const EntitlementModuleGate({
    super.key,
    required this.module,
    required this.child,
  });

  final AdminModule module;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(modulePlanLockedProvider(module));
    if (!locked) return child;
    return PlanLockedModuleView(moduleLabel: _label(module));
  }

  static String _label(AdminModule module) => switch (module) {
        AdminModule.transport => 'Transport',
        AdminModule.hostel => 'Hostel',
        AdminModule.library => 'Library',
        AdminModule.inventory => 'Inventory',
        AdminModule.alumni => 'Alumni',
        AdminModule.hr => 'HR & Payroll',
        AdminModule.director => 'Director / Multi-branch',
        AdminModule.marketing => 'Marketing',
        _ => 'This module',
      };
}

/// Read-only "module locked by plan" screen with upgrade messaging + WhatsApp
/// CTA. No payment — upgrades go to sales. Shown, never hidden (approved UX).
class PlanLockedModuleView extends ConsumerWidget {
  const PlanLockedModuleView({super.key, required this.moduleLabel});

  final String moduleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final planName = ref.watch(subscriptionProvider).planName;

    return Scaffold(
      appBar: AppBar(title: Text(moduleLabel)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: AksharaSurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: colors.primary),
                      const SizedBox(width: AksharaSpacing.s2),
                      Expanded(
                        child: Text('$moduleLabel is locked',
                            style: text.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(
                    '$moduleLabel is not included in your $planName plan. '
                    'Upgrade to unlock it — no payment is taken in the app.',
                    style: text.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AksharaSpacing.s4),
                  Wrap(
                    spacing: AksharaSpacing.s2,
                    runSpacing: AksharaSpacing.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const WhatsAppContactButton(
                        phone: kAksharaSalesWhatsApp,
                        label: 'Upgrade on WhatsApp',
                        message:
                            'Hi Akshara team, I would like to upgrade my plan '
                            'to unlock more modules.',
                      ),
                      TextButton(
                        onPressed: () => context.go(RouteNames.planEntitlements),
                        child: const Text('View plans'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
