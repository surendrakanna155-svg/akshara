import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlement_models.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/entitlements/subscription_admin_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_surface_card.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Plan slugs the screen can assign (catalog order). Display names come from the
/// live `/plans` catalog when available, else a sensible fallback label.
const List<String> _assignablePlanSlugs = [
  'trial',
  'standard',
  'professional',
  'enterprise',
];

const Map<String, String> _planFallbackNames = {
  'trial': 'Trial',
  'standard': 'Standard',
  'professional': 'Professional',
  'enterprise': 'Enterprise',
};

/// B2 — Step 4.5 · minimal superAdmin Organization Plan Assignment screen.
///
/// Select an organization, view its current plan, change the plan, save. Purpose:
/// safely assign Trial / Standard / Professional / Enterprise before enabling B2
/// in production. Read-only except the single assign action — NO billing,
/// payments, renewals, invoices, MRR, addons, white-label, or management flows.
class OrganizationPlanAssignmentScreen extends ConsumerStatefulWidget {
  const OrganizationPlanAssignmentScreen({super.key});

  @override
  ConsumerState<OrganizationPlanAssignmentScreen> createState() =>
      _OrganizationPlanAssignmentScreenState();
}

class _OrganizationPlanAssignmentScreenState
    extends ConsumerState<OrganizationPlanAssignmentScreen> {
  String? _selectedOrgId;
  String? _selectedPlan;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final canAssign = ref.watch(canAssignOrganizationPlansProvider);
    if (!canAssign) {
      return Scaffold(
        appBar: AppBar(title: const Text('Organization Plans')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AksharaSpacing.s6),
            child: Text(
              'You need the Super Admin role to assign organization plans.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final orgsAsync = ref.watch(assignableOrganizationsProvider);
    final plans = ref.watch(planCatalogProvider).valueOrNull ?? const [];

    return Scaffold(
      key: QaTestKeys.planAssignmentScreen,
      appBar: AppBar(title: const Text('Organization Plans')),
      body: SafeArea(
        child: orgsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s6),
              child: Text('Could not load organizations.\n$e',
                  textAlign: TextAlign.center),
            ),
          ),
          data: (orgs) => _buildForm(context, orgs, plans),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<OrganizationPlanAssignment> orgs,
    List<SubscriptionPlan> plans,
  ) {
    if (orgs.isEmpty) {
      return const Center(child: Text('No organizations available.'));
    }
    final selected = orgs.firstWhere(
      (o) => o.organizationId == _selectedOrgId,
      orElse: () => orgs.first,
    );
    _selectedOrgId = selected.organizationId;
    final currentPlan = selected.planSlug;
    final targetPlan = _selectedPlan ?? currentPlan;
    final changed = targetPlan != currentPlan;

    String planLabel(String slug) {
      for (final p in plans) {
        if (p.slug == slug) return p.name;
      }
      return _planFallbackNames[slug] ?? slug;
    }

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Text('Select organization',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AksharaSpacing.s2),
        AksharaSurfaceCard(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: QaTestKeys.planAssignmentOrgDropdown,
              isExpanded: true,
              value: selected.organizationId,
              items: [
                for (final o in orgs)
                  DropdownMenuItem(
                    value: o.organizationId,
                    child: Text(o.organizationName.isEmpty
                        ? o.organizationSlug
                        : o.organizationName),
                  ),
              ],
              onChanged: (id) => setState(() {
                _selectedOrgId = id;
                _selectedPlan = null; // reset to the org's current plan
              }),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        AksharaSurfaceCard(
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  color: context.colors.primary),
              const SizedBox(width: AksharaSpacing.s2),
              Text('Current plan: ',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(
                planLabel(currentPlan),
                key: QaTestKeys.planAssignmentCurrentPlan,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        Text('Change plan', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AksharaSpacing.s2),
        AksharaSurfaceCard(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: QaTestKeys.planAssignmentPlanDropdown,
              isExpanded: true,
              value: targetPlan,
              items: [
                for (final slug in _assignablePlanSlugs)
                  DropdownMenuItem(value: slug, child: Text(planLabel(slug))),
              ],
              onChanged: (slug) => setState(() => _selectedPlan = slug),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        FilledButton.icon(
          key: QaTestKeys.planAssignmentSaveButton,
          onPressed: (!changed || _saving)
              ? null
              : () => _save(selected.organizationId, targetPlan),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save plan'),
        ),
        const SizedBox(height: AksharaSpacing.s3),
        Text(
          'Assigning a plan changes entitlements only. No payment is taken.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _save(String orgId, String planSlug) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final assign = ref.read(assignSubscriptionActionProvider);
      await assign(organizationId: orgId, planSlug: planSlug);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _selectedPlan = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Plan updated.')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update plan: $e')),
      );
    }
  }
}
