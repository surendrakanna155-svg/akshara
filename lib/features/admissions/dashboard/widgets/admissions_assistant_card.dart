import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/route_names.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../admissions_intelligence_provider.dart';

/// B4 — AI Admissions Assistant card: a premium "next best actions" surface
/// grounded in the live CRM funnel. Degrades gracefully (renders nothing)
/// while loading or on error so it never blocks the dashboard.
class AdmissionsAssistantCard extends ConsumerWidget {
  const AdmissionsAssistantCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intelligence = ref.watch(admissionsIntelligenceProvider);
    if (intelligence == null) return const SizedBox.shrink();

    final colors = context.colors;
    final akshara = context.akshara;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.55),
            colors.surfaceContainerLow,
          ],
        ),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(AksharaSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(funnel: intelligence.funnel),
          const SizedBox(height: AksharaSpacing.s4),
          _FunnelStrip(funnel: intelligence.funnel),
          const SizedBox(height: AksharaSpacing.s4),
          if (intelligence.nextBestActions.isEmpty)
            _AllCaughtUp(foreground: akshara.success)
          else
            for (final action in intelligence.nextBestActions.take(4)) ...[
              _ActionTile(action: action),
              if (action != intelligence.nextBestActions.take(4).last)
                const SizedBox(height: AksharaSpacing.s3),
            ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.funnel});

  final AdmissionsFunnelSummary funnel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.auto_awesome, color: colors.onPrimary, size: 22),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Admissions Assistant',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Next best actions for your pipeline',
                style: context.text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FunnelStrip extends StatelessWidget {
  const _FunnelStrip({required this.funnel});

  final AdmissionsFunnelSummary funnel;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      '${funnel.totalLeads} leads',
      '${funnel.hotLeads} hot',
      '${funnel.conversionRate}% conversion',
      if (funnel.pendingFollowUps > 0) '${funnel.pendingFollowUps} follow-ups',
      if (funnel.unassignedLeads > 0) '${funnel.unassignedLeads} unassigned',
    ];
    return Wrap(
      spacing: AksharaSpacing.s2,
      runSpacing: AksharaSpacing.s2,
      children: [
        for (final chip in chips)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s3,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              chip,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final AdmissionsNextBestAction action;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(action.priority).resolve(context);
    final colors = context.colors;

    return Material(
      color: colors.surface.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _navigate(context, action),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.container,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(action.kind),
                    color: accent.foreground, size: 20),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            action.title,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _PriorityBadge(
                          priority: action.priority,
                          foreground: accent.foreground,
                          container: accent.container,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.detail,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    Row(
                      children: [
                        Text(
                          action.cta,
                          style: context.text.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: colors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, AdmissionsNextBestAction action) {
    final leadId = action.leadId;
    if (leadId != null && leadId.isNotEmpty) {
      context.push(RouteNames.admissionsLeadDetail(leadId));
    } else {
      context.go(RouteNames.admissionsLeads);
    }
  }

  KpiAccent _accentFor(AdmissionsActionPriority priority) {
    return switch (priority) {
      AdmissionsActionPriority.urgent => KpiAccent.error,
      AdmissionsActionPriority.high => KpiAccent.warning,
      AdmissionsActionPriority.medium => KpiAccent.primary,
      AdmissionsActionPriority.low => KpiAccent.neutral,
    };
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'stalled_hot_lead' => Icons.local_fire_department_outlined,
      'pending_follow_ups' => Icons.event_repeat_outlined,
      'unassigned_leads' => Icons.person_add_alt_outlined,
      'assign_lead' => Icons.person_add_alt_outlined,
      'stage_bottleneck' => Icons.filter_alt_outlined,
      'warm_leads_cooling' => Icons.ac_unit_outlined,
      'low_conversion' => Icons.trending_down,
      'empty_pipeline' => Icons.person_add_alt_1_outlined,
      _ => Icons.bolt_outlined,
    };
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({
    required this.priority,
    required this.foreground,
    required this.container,
  });

  final AdmissionsActionPriority priority;
  final Color foreground;
  final Color container;

  @override
  Widget build(BuildContext context) {
    final label = switch (priority) {
      AdmissionsActionPriority.urgent => 'URGENT',
      AdmissionsActionPriority.high => 'HIGH',
      AdmissionsActionPriority.medium => 'MEDIUM',
      AdmissionsActionPriority.low => 'LOW',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp({required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: foreground, size: 22),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: Text(
            'You\'re all caught up — no urgent admissions actions right now.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
