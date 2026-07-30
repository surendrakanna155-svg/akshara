import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../adaptive_ai/adaptive_ai_models.dart';
import '../../adaptive_ai/widgets/adaptive_priority_feed.dart';
import '../management_adaptive_action_routing.dart';
import '../management_models.dart';

/// Principal command overview — health, priorities, summaries, quick actions.
class ManagementPrincipalOverviewPanel extends StatelessWidget {
  const ManagementPrincipalOverviewPanel({
    super.key,
    required this.data,
  });

  final ManagementDashboardData data;

  /// WIDGET-011 (P0) — the school health score, or **null**.
  ///
  /// This used to blend `?? 68` (fee collection) with `?? 31` (net margin) and
  /// present the resulting **51** as a confident headline for a school that had
  /// recorded neither. Worse, it stripped non-digits from a money-or-percent
  /// string, so a `collectionRate` returned as `₹12,45,000` parsed as 1245000
  /// and pegged the ring at 100.
  ///
  /// Now: both inputs must be present AND must parse as a real percentage. If
  /// either is missing or is not a percentage, the score is null and the card
  /// renders "Not enough data yet". No constant is ever substituted.
  int? get _healthScore {
    final feeRate = _percent(data.feeSnapshot.collectionRate);
    final margin = _percent(
      data.kpis
          .where((k) => k.id == 'net_margin')
          .map((k) => k.value)
          .firstOrNull,
    );
    if (feeRate == null || margin == null) return null;
    return ((feeRate * _feeWeight) + (margin * _marginWeight))
        .round()
        .clamp(0, 100);
  }

  /// Blend weights for the health score. Documented and kept together so the
  /// number on the principal's screen can be reviewed; they belong on the
  /// server once it owns the figure.
  static const double _feeWeight = 0.55;
  static const double _marginWeight = 0.45;

  /// Parses a **typed percentage** such as `86%`, `86`, `86.4 %`. Returns null
  /// for anything else — notably for a currency amount (`₹12,45,000`), for an
  /// out-of-range value, and for the honest placeholders the dashboard uses
  /// when a KPI is unknown (`—`, `N/A`, empty).
  static double? _percent(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^\s*(\d{1,3}(?:\.\d+)?)\s*%?\s*$').firstMatch(raw);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || value < 0 || value > 100) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final priorities = _priorities(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Principal overview'),
        const SizedBox(height: AksharaSpacing.s3),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _HealthScoreCard(score: _healthScore)),
                  const SizedBox(width: AksharaSpacing.s4),
                  Expanded(child: _SummaryStrip(data: data)),
                ],
              );
            }
            return Column(
              children: [
                _HealthScoreCard(score: _healthScore),
                const SizedBox(height: AksharaSpacing.s4),
                _SummaryStrip(data: data),
              ],
            );
          },
        ),
        const SizedBox(height: AksharaSpacing.s4),
        if (priorities.isNotEmpty) ...[
          const AksharaSectionHeader(title: "Today's priorities"),
          const SizedBox(height: AksharaSpacing.s3),
          ...priorities,
          const SizedBox(height: AksharaSpacing.s4),
        ],
        // W2 Adaptive AI — the backend priority/recommendation feed (self-hiding
        // when empty; deterministic, explainable, RBAC-scoped). The pre-staged
        // action navigates to the module for the human to act — AI never executes.
        AdaptivePriorityFeedSection(
          persona: 'principal',
          onOpenAction: _openAdaptiveAction,
        ),
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(title: 'Quick actions'),
        const SizedBox(height: AksharaSpacing.s3),
        AksharaQuickActionGrid(
          children: [
            AksharaQuickActionCard(
              key: QaTestKeys.principalQuickAction('attendance'),
              icon: Icons.fact_check_outlined,
              label: 'Attendance',
              onTap: () => context.go(RouteNames.managementAnalytics),
            ),
            AksharaQuickActionCard(
              key: QaTestKeys.principalQuickAction('fees'),
              icon: Icons.payments_outlined,
              label: 'Fees',
              onTap: () => context.go(RouteNames.managementFinance),
            ),
            AksharaQuickActionCard(
              key: QaTestKeys.principalQuickAction('risk'),
              icon: Icons.warning_amber_outlined,
              label: 'Risk',
              onTap: () => context.go(RouteNames.managementIntelligence),
            ),
            AksharaQuickActionCard(
              key: QaTestKeys.principalQuickAction('approvals'),
              icon: Icons.task_alt_outlined,
              label: 'Approvals',
              onTap: () => context.go(RouteNames.managementApprovals),
            ),
          ],
        ),
        if (_alerts.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Alert center'),
          const SizedBox(height: AksharaSpacing.s3),
          ..._alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
              child: AksharaWarningBanner(
                message: alert,
                actionLabel: 'Review',
                onAction: () => context.go(RouteNames.managementApprovals),
              ),
            ),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s6),
      ],
    );
  }

  /// Map an Adaptive AI recommendation's (logical) deep link to the principal's
  /// management route. The human lands on the module and acts there — the AI
  /// only navigated, it never executed the action.
  void _openAdaptiveAction(BuildContext context, AdaptiveAction action) {
    context.go(managementAdaptiveActionRoute(action.deepLink));
  }

  List<Widget> _priorities(BuildContext context) {
    final items = <Widget>[];
    for (final approval in data.approvalQueue.take(3)) {
      items.add(
        AksharaSurfaceCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: AksharaRadius.chip,
                ),
                child: Icon(
                  Icons.pending_actions_outlined,
                  color: context.colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Text(
                  'Approve ${approval.title} · ${approval.amount}',
                  style: context.aksharaText.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
      items.add(const SizedBox(height: AksharaSpacing.s2));
    }
    if (data.feeSnapshot.defaulters > 0) {
      items.add(
        AksharaSurfaceCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.errorContainer,
                  borderRadius: AksharaRadius.chip,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: context.colors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Text(
                  'Follow up ${data.feeSnapshot.defaulters} fee defaulters',
                  style: context.aksharaText.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }

  List<String> get _alerts {
    final alerts = <String>[];
    if (data.feeSnapshot.defaulters > 20) {
      alerts.add(
        '${data.feeSnapshot.defaulters} students with outstanding fees (${data.feeSnapshot.outstanding}).',
      );
    }
    if (data.approvalQueue.length > 5) {
      alerts.add('${data.approvalQueue.length} items waiting in approval queue.');
    }
    if (data.aiInsight.isNotEmpty) {
      alerts.add(data.aiInsight);
    }
    return alerts;
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.score});

  /// Null when either input is unknown — WIDGET-011.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = this.score;
    if (score == null) {
      // Honest state: the ring is silent rather than confident. It is better to
      // show the principal nothing than a number derived from constants.
      return AksharaSurfaceCard(
        child: Row(
          children: [
            AksharaProgressRing(
              // Track only — an empty ring, not a "0 out of 100" verdict; the
              // label beside it says the score is unavailable.
              value: 0,
              size: 76,
              strokeWidth: 8,
              color: colors.outlineVariant,
              semanticLabel: 'School health score not available yet',
              child: Text(
                '—',
                style: context.aksharaText.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurfaceVariant,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: AksharaSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('School health score',
                      style: context.aksharaText.titleMedium),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    'Not enough data yet — needs fee collection and margin '
                    'figures for this school.',
                    style: context.aksharaText.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final tone = score >= 80
        ? colors.primary
        : score >= 60
            ? colors.tertiary
            : colors.error;
    return AksharaSurfaceCard(
      child: Row(
        children: [
          // DS V2 Phase 3 flagship — the school health score as a premium
          // progress ring (rounded arc, health-toned) replacing the raw Material
          // CircularProgressIndicator.
          AksharaProgressRing(
            value: score / 100,
            size: 76,
            strokeWidth: 8,
            color: tone,
            semanticLabel: 'School health score $score of 100',
            child: Text(
              '$score',
              style: context.aksharaText.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('School health score', style: context.aksharaText.titleMedium),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  'Blends fee collection and margin trends',
                  style: context.aksharaText.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.data});

  final ManagementDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AksharaKpiCard(
            value: data.feeSnapshot.collectionRate,
            subtitle: 'Fee collection',
            accent: KpiAccent.warning,
            icon: Icons.payments_outlined,
            style: AksharaKpiCardStyle.filled,
          ),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: AksharaKpiCard(
            value: '${data.admissionsSnapshot.joined}',
            subtitle: 'Admissions joined',
            accent: KpiAccent.primary,
            icon: Icons.person_add_outlined,
            style: AksharaKpiCardStyle.filled,
          ),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: AksharaKpiCard(
            value: '${data.feeSnapshot.defaulters}',
            subtitle: 'At-risk fees',
            accent: KpiAccent.error,
            icon: Icons.warning_amber_outlined,
            style: AksharaKpiCardStyle.filled,
          ),
        ),
      ],
    );
  }
}
