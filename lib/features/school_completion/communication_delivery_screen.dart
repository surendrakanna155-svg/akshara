import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class CommunicationDeliveryScreen extends ConsumerWidget {
  const CommunicationDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(deliveryAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Communication Delivery')),
      body: ErpAsyncBody(
        state: resolveErpAsync(analytics, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No delivery analytics available.',
        onRetry: () => ref.invalidate(deliveryAnalyticsProvider),
        builder: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(RouteNames.communicationBroadcastAdmin),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Open Broadcast Admin'),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
                title: const Text('Delivery rate'),
                trailing: Text('${data.deliveryRate}%')),
            ListTile(
                title: const Text('Sent'), trailing: Text('${data.totalSent}')),
            ListTile(
                title: const Text('Failed'),
                trailing: Text('${data.totalFailed}')),
            ListTile(
                title: const Text('Pending'),
                trailing: Text('${data.totalPending}')),
            const SizedBox(height: 12),
            const Text('By channel',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...data.byChannel.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                subtitle:
                    Text('Sent ${e.value.sent} · Failed ${e.value.failed}'),
              ),
            ),
            const Divider(),
            const Text('Recent events',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (data.recentEvents.isEmpty)
              const ListTile(title: Text('No delivery events yet')),
            ...data.recentEvents.map(
              (event) => ListTile(
                title: Text('${event.channel} → ${event.recipientLabel}'),
                subtitle: Text(event.templateCode ?? event.status),
                trailing: Text(event.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
