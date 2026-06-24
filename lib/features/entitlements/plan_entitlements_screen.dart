import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlement_models.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../core/widgets/whatsapp_contact_button.dart';
import '../../shared/widgets/akshara_surface_card.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Sales WhatsApp number for upgrade enquiries (wa.me deep-link only — no Meta
/// Business API, no in-app payment). Owner-editable; data-driven plan changes
/// happen server-side, never here.
const String kAksharaSalesWhatsApp = '9876543210';

/// A single optional capability/feature shown in the entitlement list.
class _EntitlementItem {
  const _EntitlementItem(this.slug, this.label, this.description);
  final String slug;
  final String label;
  final String description;
}

const List<_EntitlementItem> _coreModules = [
  _EntitlementItem(EntitlementSlugs.admissions, 'Admissions', 'Lead & enrolment management'),
  _EntitlementItem(EntitlementSlugs.finance, 'Finance', 'Fees, invoices & collections'),
  _EntitlementItem(EntitlementSlugs.sis, 'Student Information', 'Student records & profiles'),
  _EntitlementItem(EntitlementSlugs.management, 'Management', 'School operations dashboards'),
  _EntitlementItem(EntitlementSlugs.attendance, 'Attendance', 'Daily attendance tracking'),
  _EntitlementItem(EntitlementSlugs.exams, 'Exams', 'Exams & results'),
];

const List<_EntitlementItem> _optionalEntitlements = [
  _EntitlementItem(EntitlementSlugs.transport, 'Transport', 'Routes, vehicles & tracking'),
  _EntitlementItem(EntitlementSlugs.hostel, 'Hostel', 'Rooms, occupancy & wardens'),
  _EntitlementItem(EntitlementSlugs.library, 'Library', 'Catalogue & circulation'),
  _EntitlementItem(EntitlementSlugs.inventory, 'Inventory', 'Assets & procurement'),
  _EntitlementItem(EntitlementSlugs.alumni, 'Alumni', 'Alumni network & engagement'),
  _EntitlementItem(EntitlementSlugs.hrPayroll, 'HR & Payroll', 'Staff, leave & payroll'),
  _EntitlementItem(EntitlementSlugs.multiBranch, 'Multi-branch', 'Director & control centre'),
  _EntitlementItem(EntitlementSlugs.trustOrg, 'Trust / Organization', 'Trust-wide governance'),
  _EntitlementItem(EntitlementSlugs.parentInsights, 'Parent Insights', 'Parent insight centre'),
  _EntitlementItem(EntitlementSlugs.aiPredictions, 'AI Predictions', 'Predictive intelligence'),
];

/// Read-only Plan & Entitlements screen (B2 Step 4).
///
/// Shows the current plan, trial countdown, every module's included/locked
/// state and an upgrade CTA. Locked modules are always shown (never hidden) with
/// an upgrade message, per the approved UX. No billing/payment/renewal here —
/// upgrades route to sales over WhatsApp.
class PlanEntitlementsScreen extends ConsumerWidget {
  const PlanEntitlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final lockedCount = _optionalEntitlements
        .where((e) => !subscription.allows(e.slug))
        .length;

    return Scaffold(
      key: QaTestKeys.planEntitlementsScreen,
      appBar: AppBar(title: const Text('Plan & Entitlements')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _CurrentPlanCard(subscription: subscription),
            const SizedBox(height: AksharaSpacing.s4),
            if (lockedCount > 0) ...[
              _UpgradeCallout(planName: subscription.planName, lockedCount: lockedCount),
              const SizedBox(height: AksharaSpacing.s4),
            ],
            Text('Included in every plan',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            ..._coreModules.map((e) => _EntitlementRow(item: e, included: true)),
            const SizedBox(height: AksharaSpacing.s4),
            Text('Modules & features',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            ..._optionalEntitlements.map(
              (e) => _EntitlementRow(item: e, included: subscription.allows(e.slug)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.subscription});
  final ResolvedSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final trialDays = _trialDaysRemaining(subscription);

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: colors.primary),
              const SizedBox(width: AksharaSpacing.s2),
              Text('Current plan', style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  )),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(subscription.planName,
              key: QaTestKeys.planNameLabel, style: text.headlineSmall),
          const SizedBox(height: AksharaSpacing.s1),
          _StatusChip(status: subscription.status),
          if (trialDays != null) ...[
            const SizedBox(height: AksharaSpacing.s3),
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: AksharaSpacing.s1),
                Text(
                  trialDays > 0
                      ? '$trialDays ${trialDays == 1 ? 'day' : 'days'} remaining in trial'
                      : 'Trial period has ended',
                  key: QaTestKeys.planTrialRemainingLabel,
                  style: text.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static int? _trialDaysRemaining(ResolvedSubscription s) {
    if (s.status != SubscriptionStatus.trial || s.trialEndsAt == null) {
      return null;
    }
    final diff = s.trialEndsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, bg, fg) = switch (status) {
      SubscriptionStatus.trial =>
        ('Trial', colors.primaryContainer, colors.onPrimaryContainer),
      SubscriptionStatus.active =>
        ('Active', colors.secondaryContainer, colors.onSecondaryContainer),
      SubscriptionStatus.grace =>
        ('Grace period', colors.tertiaryContainer, colors.onTertiaryContainer),
      SubscriptionStatus.suspended =>
        ('Suspended', colors.errorContainer, colors.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s2, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _UpgradeCallout extends StatelessWidget {
  const _UpgradeCallout({required this.planName, required this.lockedCount});
  final String planName;
  final int lockedCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_open_outlined, color: colors.primary),
              const SizedBox(width: AksharaSpacing.s2),
              Expanded(
                child: Text('Unlock more with an upgrade',
                    style: text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            '$lockedCount ${lockedCount == 1 ? 'module is' : 'modules are'} not '
            'included in your $planName plan. Talk to our team to upgrade and '
            'unlock them — no payment is taken in the app.',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          const WhatsAppContactButton(
            key: QaTestKeys.planUpgradeWhatsappButton,
            phone: kAksharaSalesWhatsApp,
            label: 'Upgrade on WhatsApp',
            message:
                'Hi Akshara team, I would like to upgrade my school plan and '
                'unlock more modules.',
          ),
        ],
      ),
    );
  }
}

class _EntitlementRow extends StatelessWidget {
  const _EntitlementRow({required this.item, required this.included});
  final _EntitlementItem item;
  final bool included;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: AksharaSurfaceCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4, vertical: AksharaSpacing.s3),
        child: Row(
          children: [
            Icon(
              included ? Icons.check_circle_outline : Icons.lock_outline,
              color: included ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    included ? item.description : 'Upgrade to unlock',
                    style: text.bodySmall?.copyWith(
                      color: included
                          ? colors.onSurfaceVariant
                          : colors.primary,
                      fontWeight:
                          included ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!included)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Locked',
                    style: text.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}
