import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_models.dart';
import '../../../core/i18n/supported_languages.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'parent_communication_inbox_provider.dart';

/// Parent communication message detail with read/acknowledge tracking.
class ParentCommunicationDetailScreen extends ConsumerStatefulWidget {
  const ParentCommunicationDetailScreen({
    super.key,
    required this.messageId,
    this.onNotificationsTap,
  });

  final String messageId;
  final VoidCallback? onNotificationsTap;

  @override
  ConsumerState<ParentCommunicationDetailScreen> createState() =>
      _ParentCommunicationDetailScreenState();
}

class _ParentCommunicationDetailScreenState
    extends ConsumerState<ParentCommunicationDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markParentCommunicationRead(ref, widget.messageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(parentCommunicationMessageProvider(widget.messageId));
    if (message == null) {
      return const Scaffold(
        body: AksharaEmptyState(
          message: 'Message not found.',
          icon: Icons.mail_outline,
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Message',
        subtitle: message.senderName,
        onNotificationsTap: widget.onNotificationsTap,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          _MetaRow(label: 'Student', value: message.studentName),
          _MetaRow(label: 'Reason', value: message.reasonLabel),
          _MetaRow(label: 'Sent', value: message.sentAtLabel),
          _MetaRow(label: 'Sender', value: message.senderName),
          _MetaRow(label: 'Channel', value: message.channelsLabel),
          _MetaRow(
            label: 'Status',
            value: message.deliveryStatusLabel,
          ),
          const SizedBox(height: AksharaSpacing.s3),
          const AksharaSectionHeader(title: 'Message'),
          const SizedBox(height: AksharaSpacing.s2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Text(
                message.displayBody,
                style: context.aksharaText.bodyLarge,
              ),
            ),
          ),
          if (message.targetLanguage != AksharaLanguage.english) ...[
            const SizedBox(height: AksharaSpacing.s3),
            const AksharaSectionHeader(title: 'Original (English)'),
            const SizedBox(height: AksharaSpacing.s2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                child: Text(
                  message.originalMessage,
                  style: context.aksharaText.bodyMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          if (message.deliveryStatus !=
              ParentCommunicationDeliveryStatus.acknowledged)
            FilledButton.icon(
              onPressed: () async {
                await acknowledgeParentCommunication(ref, widget.messageId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message acknowledged')),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Acknowledge'),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: context.aksharaText.labelMedium,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
