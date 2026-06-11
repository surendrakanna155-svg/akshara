import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'evolution_providers.dart';

class GrowthPlatformScreen extends ConsumerWidget {
  const GrowthPlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(growthDashboardProvider);
    final funnel = ref.watch(growthFunnelProvider);
    final campaigns = ref.watch(growthCampaignsProvider);
    final inquiries = ref.watch(growthInquiriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admissions Growth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await ref.read(evolutionRepositoryProvider).createGrowthInquiry(
                    query: ref.read(evolutionQueryProvider),
                    parentName: 'New Parent',
                    source: 'website',
                    gradeInterest: 'Grade 1',
                  );
              ref.invalidate(growthInquiriesProvider);
              ref.invalidate(growthDashboardProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ref.read(evolutionRepositoryProvider).createGrowthCampaign(
                query: ref.read(evolutionQueryProvider),
                name: 'New Campaign',
                channel: 'facebook',
                budgetInr: 15000,
              );
          ref.invalidate(growthCampaignsProvider);
          ref.invalidate(growthDashboardProvider);
        },
        label: const Text('New campaign'),
        icon: const Icon(Icons.campaign_outlined),
      ),
      body: dashboard.when(
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _kpi('Inquiries', '${d.totalInquiries}')),
                Expanded(child: _kpi('Conversion', '${d.conversionRate}%')),
                Expanded(child: _kpi('Active campaigns', '${d.activeCampaigns}')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Conversion funnel', style: Theme.of(context).textTheme.titleMedium),
            funnel.when(
              data: (f) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...f.stages.map(
                    (s) => ListTile(
                      dense: true,
                      title: Text('${s['stage']}'),
                      trailing: Text('${s['count']}'),
                    ),
                  ),
                  if (f.sourceAttribution.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Source attribution', style: Theme.of(context).textTheme.labelLarge),
                    ...f.sourceAttribution.map(
                      (s) => Text('${s['source']}: ${s['inquiries']} inquiries, ${s['converted']} converted'),
                    ),
                  ],
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            Text('Campaigns', style: Theme.of(context).textTheme.titleMedium),
            campaigns.when(
              data: (items) => items.isEmpty
                  ? const AksharaEmptyState(message: 'No campaigns yet.')
                  : Column(
                      children: items
                          .map(
                            (c) => ListTile(
                              title: Text(c.name),
                              subtitle: Text('${c.channel} · ${c.status}'),
                              trailing: c.budgetInr != null ? Text('₹${c.budgetInr!.toStringAsFixed(0)}') : null,
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            Text('Inquiries & follow-ups', style: Theme.of(context).textTheme.titleMedium),
            inquiries.when(
              data: (items) => items.isEmpty
                  ? const AksharaEmptyState(message: 'No inquiries yet.')
                  : Column(
                      children: items
                          .map(
                            (i) => ListTile(
                              title: Text(i.parentName),
                              subtitle: Text(
                                '${i.source} · ${i.gradeInterest ?? ''}${i.leadId != null ? ' · lead ${i.leadId}' : ''}',
                              ),
                              trailing: i.status == 'converted'
                                  ? Chip(label: Text(i.status))
                                  : TextButton(
                                      onPressed: () async {
                                        await ref.read(evolutionRepositoryProvider).convertGrowthInquiry(
                                              query: ref.read(evolutionQueryProvider),
                                              inquiryId: i.id,
                                            );
                                        ref.invalidate(growthInquiriesProvider);
                                        ref.invalidate(growthDashboardProvider);
                                        ref.invalidate(growthFunnelProvider);
                                      },
                                      child: const Text('Convert'),
                                    ),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading growth dashboard'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load growth platform.',
          onRetry: () => ref.invalidate(growthDashboardProvider),
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}
