import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/akshara_error_state.dart';
import '../../../../shared/widgets/akshara_loading_state.dart';
import '../../../../shared/widgets/akshara_section_header.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../widgets/control_center_segment_panel.dart';

/// ACC-03 — Subscriptions & Plans.
class ControlCenterSubscriptionsScreen extends ConsumerWidget {
  const ControlCenterSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterSubscriptionsLoadingProvider);
    final isError = ref.watch(controlCenterSubscriptionsErrorProvider);
    final data = ref.watch(controlCenterSubscriptionsProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.subscriptions,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required ControlCenterSubscriptionsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading subscriptions',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load subscription plans.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Subscription data is not available.',
      );
    }

    final text = context.aksharaText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Subscription plans'),
        Text(
          '${data.expiringCount} expiring · ${data.renewalRatePercent}% renewal rate',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        for (final plan in data.plans) ...[
          _PlanCard(plan: plan),
          const SizedBox(height: AksharaSpacing.s4),
        ],
        ControlCenterSegmentPanel(
          title: 'Plan distribution',
          segments: data.planDistribution,
          height: 220,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final SubscriptionPlanInfo plan;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: '${plan.plan.name} plan, ${plan.schoolCount} schools',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.plan.name.toUpperCase(),
                style: text.titleMedium,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '₹${plan.monthlyPriceLakhs}L/month · ${plan.schoolCount} schools'
                '${plan.dedicatedDb ? ' · Dedicated DB' : ''}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                plan.features.join(' · '),
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
