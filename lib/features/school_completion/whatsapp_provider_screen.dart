import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

/// Read-only WhatsApp provider status for school admins.
/// Credentials and provider configuration are managed by platform super admin only.
class WhatsAppProviderScreen extends ConsumerWidget {
  const WhatsAppProviderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(whatsAppProviderConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Status')),
      body: config.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            const AksharaWarningBanner(
              message:
                  'Provider credentials are managed by platform super admin. School admins can view status and delivery analytics only.',
            ),
            ListTile(
              title: const Text('Provider'),
              trailing: Text(data.provider.toUpperCase()),
            ),
            ListTile(
              title: const Text('Status'),
              trailing: Text(data.isActive ? 'Active' : 'Inactive'),
            ),
            if (data.senderId != null)
              ListTile(title: const Text('Sender ID'), trailing: Text(data.senderId!)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Delivery analytics'),
              subtitle: const Text('View sent, failed, and pending messages'),
              onTap: () => context.push(RouteNames.communicationDelivery),
            ),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading WhatsApp config'),
        error: (e, _) => AksharaErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(whatsAppProviderConfigProvider),
        ),
      ),
    );
  }
}
