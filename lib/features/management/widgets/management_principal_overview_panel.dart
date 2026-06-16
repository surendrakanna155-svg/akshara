import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../management_models.dart';

/// Principal command overview — health, priorities, summaries, quick actions.
class ManagementPrincipalOverviewPanel extends StatelessWidget {
  const ManagementPrincipalOverviewPanel({
    super.key,
    required this.data,
  });

  final ManagementDashboardData data;

  int get _healthScore {
    final feeRate = int.tryParse(
          data.feeSnapshot.collectionRate.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        68;
    final margin = int.tryParse(
          data.kpis
                  .where((k) => k.id == 'net_margin')
                  .map((k) => k.value)
                  .firstOrNull
                  ?.replaceAll(RegExp(r'[^0-9]'), '') ??
              '31',
        ) ??
        31;
    return ((feeRate * 0.55) + (margin * 0.45)).round().clamp(0, 100);
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
              onTap: () => context.go(RouteNames.managementTasks),
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
                onAction: () => context.go(RouteNames.managementTasks),
              ),
            ),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s6),
      ],
    );
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

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = score >= 80
        ? colors.primary
        : score >= 60
            ? colors.tertiary
            : colors.error;
    return AksharaSurfaceCard(
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  color: tone,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
                Text('$score', style: context.aksharaText.headlineSmall),
              ],
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
