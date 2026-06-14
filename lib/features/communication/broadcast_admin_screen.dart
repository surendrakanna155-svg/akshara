import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/interfaces/communication_repository.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'communication_mutations_provider.dart';
import 'communication_providers.dart';

class BroadcastAdminScreen extends ConsumerStatefulWidget {
  const BroadcastAdminScreen({super.key});

  @override
  ConsumerState<BroadcastAdminScreen> createState() =>
      _BroadcastAdminScreenState();
}

class _BroadcastAdminScreenState extends ConsumerState<BroadcastAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _audienceController = TextEditingController(text: 'all_parents');
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _templateCodeController = TextEditingController();
  final _templateChannelController = TextEditingController(text: 'push');
  final _templateSubjectController = TextEditingController();
  final _templateBodyController = TextEditingController();
  final _templateVariablesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audienceController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _templateCodeController.dispose();
    _templateChannelController.dispose();
    _templateSubjectController.dispose();
    _templateBodyController.dispose();
    _templateVariablesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(communicationTemplatesFutureProvider);
    final historyState = ref.watch(communicationBroadcastHistoryFutureProvider);
    final sending = ref.watch(sendBroadcastProvider).isLoading;
    final savingTemplate = ref.watch(saveTemplateProvider).isLoading;

    return Scaffold(
      key: QaTestKeys.communicationBroadcastAdminScreen,
      appBar: AppBar(
        title: const Text('Broadcast Admin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Compose'),
            Tab(text: 'Templates'),
            Tab(text: 'History'),
            Tab(text: 'Delivery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ComposeTab(
            audienceController: _audienceController,
            titleController: _titleController,
            bodyController: _bodyController,
            isLoading: sending,
            onSend: _sendBroadcast,
          ),
          _TemplatesTab(
            templatesState: templatesState,
            codeController: _templateCodeController,
            channelController: _templateChannelController,
            subjectController: _templateSubjectController,
            bodyController: _templateBodyController,
            variablesController: _templateVariablesController,
            isLoading: savingTemplate,
            onSaveTemplate: _saveTemplate,
          ),
          _HistoryTab(historyState: historyState),
          _DeliveryTab(historyState: historyState),
        ],
      ),
    );
  }

  Future<void> _sendBroadcast() async {
    final request = BroadcastRequest(
      audience: _audienceController.text.trim(),
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
    );
    await ref.read(sendBroadcastProvider.notifier).execute(request);
    if (!mounted) return;
    final result = ref.read(sendBroadcastProvider).valueOrNull;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Broadcast sent to ${result.recipientCount} recipients (${result.status})',
          ),
        ),
      );
    }
  }

  Future<void> _saveTemplate() async {
    final variables = _templateVariablesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    await ref.read(saveTemplateProvider.notifier).execute(
          code: _templateCodeController.text.trim(),
          channel: _templateChannelController.text.trim(),
          subjectTemplate: _templateSubjectController.text.trim().isEmpty
              ? null
              : _templateSubjectController.text.trim(),
          bodyTemplate: _templateBodyController.text.trim(),
          variables: variables,
        );
    if (!mounted) return;
    if (ref.read(saveTemplateProvider).valueOrNull != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved')),
      );
    }
  }
}

class _ComposeTab extends StatelessWidget {
  const _ComposeTab({
    required this.audienceController,
    required this.titleController,
    required this.bodyController,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController audienceController;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool isLoading;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: audienceController,
          decoration: const InputDecoration(labelText: 'Audience'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bodyController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Body'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: QaTestKeys.communicationBroadcastSendButton,
          onPressed: isLoading ? null : onSend,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Send broadcast'),
        ),
      ],
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({
    required this.templatesState,
    required this.codeController,
    required this.channelController,
    required this.subjectController,
    required this.bodyController,
    required this.variablesController,
    required this.isLoading,
    required this.onSaveTemplate,
  });

  final AsyncValue<List<CommunicationTemplate>> templatesState;
  final TextEditingController codeController;
  final TextEditingController channelController;
  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final TextEditingController variablesController;
  final bool isLoading;
  final Future<void> Function() onSaveTemplate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Existing templates',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        templatesState.when(
          data: (items) => Column(
            children: [
              for (final template in items)
                ListTile(
                  dense: true,
                  title: Text(template.code),
                  subtitle:
                      Text('${template.channel} · ${template.bodyTemplate}'),
                ),
            ],
          ),
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState(message: '$error'),
        ),
        const Divider(),
        TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: 'Template code'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: channelController,
          decoration: const InputDecoration(labelText: 'Channel'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: subjectController,
          decoration: const InputDecoration(labelText: 'Subject (optional)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: bodyController,
          decoration: const InputDecoration(labelText: 'Body template'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: variablesController,
          decoration:
              const InputDecoration(labelText: 'Variables (comma separated)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: QaTestKeys.communicationTemplateSaveButton,
          onPressed: isLoading ? null : onSaveTemplate,
          child: Text(isLoading ? 'Saving...' : 'Save template'),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.historyState});

  final AsyncValue<List<BroadcastHistoryItem>> historyState;

  @override
  Widget build(BuildContext context) {
    return historyState.when(
      data: (items) => ListView.builder(
        key: QaTestKeys.communicationBroadcastHistoryList,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.title),
            subtitle: Text('${item.audience} · ${item.sentAt}'),
            trailing: Text(item.status),
          );
        },
      ),
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState(message: '$error'),
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({required this.historyState});

  final AsyncValue<List<BroadcastHistoryItem>> historyState;

  @override
  Widget build(BuildContext context) {
    return historyState.when(
      data: (items) {
        final total =
            items.fold<int>(0, (sum, item) => sum + item.recipientCount);
        final sent = items.where((item) => item.status == 'sent').length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
                title: const Text('Total campaigns'),
                trailing: Text('${items.length}')),
            ListTile(
                title: const Text('Total recipients reached'),
                trailing: Text('$total')),
            ListTile(
                title: const Text('Sent campaigns'), trailing: Text('$sent')),
          ],
        );
      },
      loading: () => const AksharaLoadingState(),
      error: (error, _) => AksharaErrorState(message: '$error'),
    );
  }
}
