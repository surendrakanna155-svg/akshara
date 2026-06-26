import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/security/permissions.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import 'evolution_models.dart';
import 'evolution_mutations_provider.dart';
import 'evolution_providers.dart';
import 'evolution_requests.dart';
import '../../theme/spacing.dart';

class GrowthPlatformScreen extends ConsumerWidget {
  const GrowthPlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(growthDashboardProvider);
    final funnel = ref.watch(growthFunnelProvider);
    final campaigns = ref.watch(growthCampaignsProvider);
    final inquiries = ref.watch(growthInquiriesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: QaTestKeys.growthPlatformScreen,
        appBar: AppBar(
          title: const Text('Admissions Growth'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Campaigns'),
              Tab(text: 'Inquiries'),
            ],
          ),
          actions: [
            AksharaManageAction(
              permission: Permission.manageGrowthPlatform,
              child: TextButton.icon(
                key: QaTestKeys.growthCreateInquiryButton,
                onPressed: () => _showCreateInquiryDialog(context, ref),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('New inquiry'),
              ),
            ),
          ],
        ),
        floatingActionButton: AksharaManageAction(
          permission: Permission.manageGrowthPlatform,
          child: FloatingActionButton.extended(
            key: QaTestKeys.growthCreateCampaignButton,
            onPressed: () => _showCreateCampaignDialog(context, ref),
            label: const Text('New campaign'),
            icon: const Icon(Icons.campaign_outlined),
          ),
        ),
        body: TabBarView(
          children: [
            _buildDashboardTab(context, ref, dashboard, funnel),
            _buildCampaignsTab(ref, campaigns),
            _buildInquiriesTab(ref, inquiries),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GrowthDashboard> dashboard,
    AsyncValue<GrowthFunnel> funnel,
  ) {
    return dashboard.when(
      data: (d) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Row(
            children: [
              Expanded(child: _kpi('Inquiries', '${d.totalInquiries}')),
              Expanded(child: _kpi('Conversion', '${d.conversionRate}%')),
              Expanded(child: _kpi('Active campaigns', '${d.activeCampaigns}')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Conversion funnel', style: context.aksharaText.titleMedium),
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
                  Text('Source attribution', style: context.aksharaText.labelLarge),
                  ...f.sourceAttribution.map(
                    (s) => Text('${s['source']}: ${s['inquiries']} inquiries, ${s['converted']} converted'),
                  ),
                ],
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () => ref.invalidate(growthFunnelProvider),
            ),
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading growth dashboard'),
      error: (e, _) => AksharaErrorState(
        message: 'Unable to load growth platform.',
        onRetry: () {
          ref.invalidate(growthDashboardProvider);
          ref.invalidate(growthFunnelProvider);
        },
      ),
    );
  }

  Widget _buildCampaignsTab(WidgetRef ref, AsyncValue<List<GrowthCampaign>> campaigns) {
    return campaigns.when(
      data: (items) => items.isEmpty
          ? const AksharaEmptyState(message: 'No campaigns yet.')
          : ListView(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              children: [
                for (final c in items)
                  Card(
                    child: ListTile(
                      key: QaTestKeys.growthCampaignRow(c.id),
                      title: Text(c.name),
                      subtitle: Text(
                        '${c.channel} · ${c.status} · ${c.audience}${c.scheduledAt != null ? ' · scheduled ${c.scheduledAt}' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (c.budgetInr != null) Text('₹${c.budgetInr!.toStringAsFixed(0)}'),
                          AksharaManageAction(
                            permission: Permission.manageGrowthPlatform,
                            child: TextButton(
                              key: c.status == 'paused'
                                  ? QaTestKeys.growthActivateCampaignButton(c.id)
                                  : QaTestKeys.growthPauseCampaignButton(c.id),
                              onPressed: () async {
                                if (c.status == 'paused') {
                                  await ref.read(updateGrowthCampaignProvider.notifier).execute(
                                        campaignId: c.id,
                                        request: const UpdateGrowthCampaignRequest(status: 'active'),
                                      );
                                } else {
                                  await ref.read(pauseGrowthCampaignProvider.notifier).execute(c.id);
                                }
                              },
                              child: Text(c.status == 'paused' ? 'Activate' : 'Pause'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(e),
        onRetry: () => ref.invalidate(growthCampaignsProvider),
      ),
    );
  }

  Widget _buildInquiriesTab(WidgetRef ref, AsyncValue<List<GrowthInquiry>> inquiries) {
    return inquiries.when(
      data: (items) => items.isEmpty
          ? const AksharaEmptyState(message: 'No inquiries yet.')
          : ListView(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              children: [
                for (final i in items)
                  Card(
                    child: ListTile(
                      key: QaTestKeys.growthInquiryRow(i.id),
                      title: Text(i.parentName),
                      subtitle: Text(
                        '${i.source} · ${i.gradeInterest ?? ''}${i.leadId != null ? ' · lead ${i.leadId}' : ''}',
                      ),
                      trailing: i.status == 'converted'
                          ? Chip(label: Text(i.status))
                          : AksharaManageAction(
                              permission: Permission.manageGrowthPlatform,
                              child: TextButton(
                                key: QaTestKeys.growthConvertInquiryButton(i.id),
                                onPressed: () async {
                                  await ref.read(convertGrowthInquiryProvider.notifier).execute(i.id);
                                },
                                child: const Text('Convert'),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(e),
        onRetry: () => ref.invalidate(growthInquiriesProvider),
      ),
    );
  }

  Future<void> _showCreateCampaignDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final channelController = TextEditingController(text: 'facebook');
    final budgetController = TextEditingController();
    final audienceController = TextEditingController(text: 'all');
    DateTime? scheduledAt;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Create campaign'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: QaTestKeys.growthCampaignNameField,
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Campaign name'),
                  ),
                  TextField(
                    key: QaTestKeys.growthCampaignChannelField,
                    controller: channelController,
                    decoration: const InputDecoration(labelText: 'Channel'),
                  ),
                  TextField(
                    key: QaTestKeys.growthCampaignBudgetField,
                    controller: budgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Budget (INR)'),
                  ),
                  TextField(
                    key: QaTestKeys.growthCampaignAudienceField,
                    controller: audienceController,
                    decoration: const InputDecoration(labelText: 'Audience'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: QaTestKeys.growthCampaignScheduleButton,
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => scheduledAt = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        scheduledAt == null
                            ? 'Schedule date'
                            : 'Scheduled: ${scheduledAt!.toIso8601String().split('T').first}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: QaTestKeys.growthCampaignCreateSubmitButton,
                onPressed: () async {
                  final budget = double.tryParse(budgetController.text.trim());
                  await ref.read(createGrowthCampaignProvider.notifier).execute(
                        CreateGrowthCampaignRequest(
                          name: nameController.text.trim(),
                          channel: channelController.text.trim(),
                          budgetInr: budget,
                          audience: audienceController.text.trim().isEmpty
                              ? 'all'
                              : audienceController.text.trim(),
                          scheduledAt: scheduledAt?.toIso8601String(),
                        ),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateInquiryDialog(BuildContext context, WidgetRef ref) async {
    final parentController = TextEditingController();
    final sourceController = TextEditingController(text: 'website');
    final gradeController = TextEditingController(text: 'Grade 1');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create inquiry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: QaTestKeys.growthInquiryParentField,
              controller: parentController,
              decoration: const InputDecoration(labelText: 'Parent name'),
            ),
            TextField(
              key: QaTestKeys.growthInquirySourceField,
              controller: sourceController,
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            TextField(
              key: QaTestKeys.growthInquiryGradeField,
              controller: gradeController,
              decoration: const InputDecoration(labelText: 'Grade interest'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.growthInquiryCreateSubmitButton,
            onPressed: () async {
              await ref.read(createGrowthInquiryProvider.notifier).execute(
                    parentName: parentController.text.trim(),
                    source: sourceController.text.trim(),
                    gradeInterest: gradeController.text.trim(),
                  );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
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
