import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../transport_models.dart';
import '../transport_mutations_provider.dart';
import '../transport_providers.dart';
import '../transport_requests.dart';

/// TRN-2/TRN-8 — document-expiry tracker. Lists vehicle + driver documents whose
/// ISO expiry is soon (within 30 days) or already expired, colour-coded, with a
/// "Send reminder" action that fans out the in-app broadcast (TRN-8).
class TransportDocumentExpirySection extends ConsumerWidget {
  const TransportDocumentExpirySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transportDocumentExpiriesProvider);
    final text = context.aksharaText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AksharaSectionHeader(title: 'Document expiry tracker'),
            ),
            AksharaManageAction(
              permission: Permission.manageTransport,
              child: OutlinedButton.icon(
                key: QaTestKeys.transportSendExpiryReminderButton,
                onPressed: () => _sendReminder(context, ref),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Send reminder'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s6),
            child: AksharaLoadingState(semanticLabel: 'Loading document expiries'),
          ),
          error: (_, __) => const AksharaErrorState(
            message: 'Unable to load document expiries.',
          ),
          data: (docs) {
            final tracked = docs
                .where((d) => d.isExpired || d.isSoon)
                .toList(growable: false);
            if (tracked.isEmpty) {
              return Text(
                'No documents expiring within 30 days.',
                style: text.bodySmall,
              );
            }
            return Semantics(
              container: true,
              label: 'Document expiries, ${tracked.length} items',
              child: Column(
                children: [
                  for (final doc in tracked) ...[
                    _ExpiryTile(doc: doc),
                    const SizedBox(height: AksharaSpacing.s2),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _sendReminder(BuildContext context, WidgetRef ref) async {
    try {
      final count = await ref
          .read(sendDocumentExpiryReminderProvider.notifier)
          .execute(const SendTransportDocumentExpiryReminderRequest());
      if (!context.mounted || count == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.transportExpiryReminderSnackbar,
          content: Text(
            count == 0
                ? 'No documents due — no reminder sent.'
                : 'Reminder sent for $count expiring document(s).',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }
}

class _ExpiryTile extends StatelessWidget {
  const _ExpiryTile({required this.doc});

  final TransportDocumentExpiry doc;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final (label, tone) = doc.isExpired
        ? ('Expired', KpiAccent.error)
        : ('In ${doc.daysUntil}d', KpiAccent.warning);

    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(
          doc.isExpired ? Icons.error_outline : Icons.warning_amber_outlined,
          color: doc.isExpired ? Colors.red : Colors.orange,
        ),
        title: Text('${doc.subject} · ${doc.document}', style: text.titleSmall),
        subtitle: Text('Expires ${doc.expiresOn}', style: text.bodySmall),
        trailing: AksharaStatusChip(label: label, tone: tone),
      ),
    );
  }
}
