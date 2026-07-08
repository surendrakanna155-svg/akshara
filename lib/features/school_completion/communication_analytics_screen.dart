import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async/erp_async_state.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class CommunicationAnalyticsScreen extends ConsumerWidget {
  const CommunicationAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(communicationAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Communication Analytics')),
      body: ErpAsyncBody(
        state: resolveErpAsync(analytics, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No communication analytics available.',
        onRetry: () => ref.invalidate(communicationAnalyticsProvider),
        builder: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _sectionTitle('Campaign analytics'),
            ListTile(
              title: const Text('Active campaigns'),
              trailing: Text('${data.campaigns.activeCampaigns}/${data.campaigns.totalCampaigns}'),
            ),
            ListTile(
              title: const Text('Aggregate open rate'),
              trailing: Text('${data.campaigns.aggregateOpenRate}%'),
            ),
            ListTile(
              title: const Text('Aggregate response rate'),
              trailing: Text('${data.campaigns.aggregateResponseRate}%'),
            ),
            ...data.campaigns.campaigns.map(
              (c) => ListTile(
                title: Text(c.campaignName),
                subtitle: Text('${c.channel} · ${c.status}'),
                trailing: Text('${c.openRate}% open'),
              ),
            ),
            const Divider(),
            _sectionTitle('Delivery analytics'),
            ListTile(
              title: const Text('Delivery rate'),
              trailing: Text('${data.delivery.deliveryRate}%'),
            ),
            ListTile(
              title: const Text('Last 7 days'),
              subtitle: Text('${data.delivery.last7DaysSent} sent · ${data.delivery.last7DaysFailed} failed'),
            ),
            ...data.delivery.byChannel.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                subtitle: Text('Sent ${e.value.sent} · Failed ${e.value.failed}'),
              ),
            ),
            const Divider(),
            _sectionTitle('Communication effectiveness'),
            ListTile(
              title: const Text('Effectiveness score'),
              trailing: Text('${data.effectiveness.effectivenessScore}/100',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('Open / response rate'),
              subtitle: Text('${data.effectiveness.openRate}% · ${data.effectiveness.responseRate}%'),
            ),
            ...data.effectiveness.topTemplates.map(
              (t) => ListTile(
                title: Text(t.templateCode),
                trailing: Text('${t.openRate}% · ${t.sent} sent'),
              ),
            ),
            const Divider(),
            _sectionTitle('Parent engagement'),
            ListTile(
              title: const Text('Average engagement score'),
              trailing: Text('${data.parentEngagement.averageEngagementScore}'),
            ),
            ListTile(
              title: const Text('Active parents (30d)'),
              trailing: Text('${data.parentEngagement.activeParents30d}'),
            ),
            ListTile(
              title: const Text('Low engagement parents'),
              trailing: Text('${data.parentEngagement.lowEngagementParents}'),
            ),
            const Divider(),
            _sectionTitle('Parent adoption'),
            ListTile(
              title: const Text('Adoption rate'),
              trailing: Text('${data.parentAdoption.adoptionRate}%'),
            ),
            ListTile(
              title: Text('${data.parentAdoption.activeParents}/${data.parentAdoption.totalParents} active'),
              subtitle: Text('${data.parentAdoption.newActivations30d} new activations (30d)'),
            ),
            ...data.parentAdoption.adoptionByGrade.map(
              (g) => ListTile(
                title: Text(g.gradeLabel),
                trailing: Text('${g.rate}% (${g.active}/${g.total})'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );
}
