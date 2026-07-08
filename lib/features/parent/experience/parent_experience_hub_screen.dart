import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../theme/theme_extensions.dart';
import '../../phase5/phase5_models.dart';
import '../../phase5/phase5_providers.dart';
import '../parent_active_child_provider.dart';
import '../widgets/parent_child_switcher_sheet.dart';
import '../../../theme/spacing.dart';

/// Parent Experience Hub — production polish (v10.4).
class ParentExperienceHubScreen extends ConsumerStatefulWidget {
  const ParentExperienceHubScreen({super.key, this.studentId, this.initialTab = 0});

  final String? studentId;
  final int initialTab;

  @override
  ConsumerState<ParentExperienceHubScreen> createState() => _ParentExperienceHubScreenState();
}

class _ParentExperienceHubScreenState extends ConsumerState<ParentExperienceHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _ackInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _studentId =>
      widget.studentId ?? ref.read(parentActiveStudentIdProvider);

  Future<void> _ackItem(ParentInventoryItem item, String type) async {
    if (_ackInFlight) return;
    setState(() => _ackInFlight = true);
    try {
      await ref.read(parentExperienceRepositoryProvider).acknowledgeItem(
            query: ref.read(phase5QueryProvider),
            studentId: _studentId,
            distributionId: item.id,
            acknowledgementType: type,
          );
      ref.invalidate(parentExperienceHubProvider(_studentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'replacement_requested'
                  ? 'Replacement request submitted'
                  : 'Item receipt acknowledged',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ackInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = ref.watch(parentExperienceHubProvider(_studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Experience'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch child',
            onPressed: () => showParentChildSwitcherSheet(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Academics'),
            Tab(text: 'Attendance'),
            Tab(text: 'Inventory'),
            Tab(text: 'Communication'),
            Tab(text: 'Guidance'),
          ],
        ),
      ),
      body: ErpAsyncBody(
        state: resolveErpAsync(hub, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No experience hub data available.',
        onRetry: () => ref.invalidate(parentExperienceHubProvider(_studentId)),
        builder: (h) => TabBarView(
          controller: _tabs,
          children: [
            _OverviewTab(h: h, onOpenInventory: () => _tabs.animateTo(3)),
            _AcademicsTab(h: h),
            _AttendanceTab(h: h),
            _InventoryTab(
              h: h,
              ackInFlight: _ackInFlight,
              onAck: _ackItem,
            ),
            _CommunicationTab(h: h),
            _GuidanceTab(h: h),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.h, required this.onOpenInventory});
  final ParentExperienceHub h;
  final VoidCallback onOpenInventory;

  @override
  Widget build(BuildContext context) {
    final o = h.overview;
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Card(
          child: ListTile(
            title: Text(o.childName),
            subtitle: Text(o.classLabel),
            trailing: Chip(label: Text('Risk: ${o.riskLevel}')),
          ),
        ),
        if (o.pendingInventoryAcks > 0)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              title: Text('${o.pendingInventoryAcks} items awaiting acknowledgement'),
              trailing: TextButton(onPressed: onOpenInventory, child: const Text('Review')),
            ),
          ),
        if (o.pendingPaymentRequests > 0)
          ListTile(
            title: const Text('Pending payment requests'),
            trailing: Text('${o.pendingPaymentRequests}'),
          ),
        ListTile(
          title: const Text('Homework intelligence'),
          subtitle: Text(h.homeworkIntelligence.weakTopics.join(', ')),
        ),
      ],
    );
  }
}

class _AcademicsTab extends StatelessWidget {
  const _AcademicsTab({required this.h});
  final ParentExperienceHub h;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        ListTile(
          title: const Text('Homework progress'),
          subtitle: Text(
            '${h.academics.homeworkSubmitted}/${h.academics.homeworkTotal} submitted',
          ),
        ),
        const Divider(),
        Text('Homework intelligence', style: context.aksharaText.titleMedium),
        ...h.homeworkIntelligence.weakTopics.map(
          (t) => ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(t),
          ),
        ),
        const Divider(),
        Text('Suggested revision', style: context.aksharaText.titleMedium),
        ...h.homeworkIntelligence.suggestedRevision.map((s) => ListTile(title: Text(s))),
        const Divider(),
        Text('Teacher recommendations', style: context.aksharaText.titleMedium),
        ...h.homeworkIntelligence.teacherRecommendations.map((r) => ListTile(title: Text(r))),
        const Divider(),
        ...h.academics.recentExams.map(
          (e) => ListTile(title: Text(e.title), trailing: Text('${e.avgPct}%')),
        ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.h});
  final ParentExperienceHub h;

  @override
  Widget build(BuildContext context) {
    final a = h.attendance;
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        ListTile(title: const Text('Present'), trailing: Text('${a.present}')),
        ListTile(title: const Text('Absent'), trailing: Text('${a.absent}')),
        ListTile(title: const Text('Attendance %'), trailing: Text('${a.pct}%')),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({
    required this.h,
    required this.ackInFlight,
    required this.onAck,
  });

  final ParentExperienceHub h;
  final bool ackInFlight;
  final Future<void> Function(ParentInventoryItem item, String type) onAck;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        ListTile(title: const Text('Issued'), trailing: Text('${h.inventory.issued}')),
        ListTile(title: const Text('Pending ack'), trailing: Text('${h.inventory.pending}')),
        const Divider(),
        ...h.inventory.items.map((i) {
          final needsAck = i.status == 'distributed';
          final canReplace = ['distributed', 'parent_acknowledged', 'missing', 'damaged']
              .contains(i.status);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(i.itemName),
                    subtitle: Text('${i.category} · ${i.status}'),
                    trailing: Text('x${i.quantity}'),
                  ),
                  if (needsAck || canReplace)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (needsAck)
                          FilledButton(
                            onPressed: ackInFlight ? null : () => onAck(i, 'received'),
                            child: const Text('Item received'),
                          ),
                        if (canReplace)
                          OutlinedButton(
                            onPressed: ackInFlight ? null : () => onAck(i, 'replacement_requested'),
                            child: const Text('Request replacement'),
                          ),
                      ],
                    ),
                  if (i.status == 'payment_pending')
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
                      child: Text('Payment request pending for replacement'),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CommunicationTab extends StatelessWidget {
  const _CommunicationTab({required this.h});
  final ParentExperienceHub h;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        ListTile(
          title: const Text('Recent messages'),
          trailing: Text('${h.communication.recentCount}'),
        ),
        if (h.communication.lastMessageAt != null)
          ListTile(
            title: const Text('Last message'),
            subtitle: Text(h.communication.lastMessageAt!),
          ),
      ],
    );
  }
}

class _GuidanceTab extends StatelessWidget {
  const _GuidanceTab({required this.h});
  final ParentExperienceHub h;

  @override
  Widget build(BuildContext context) {
    if (!h.guidance.available && h.guidance.reports.isEmpty) {
      return const AksharaEmptyState(message: 'No guidance reports available yet');
    }
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (h.guidance.summary != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: Text(h.guidance.summary!),
            ),
          ),
        const SizedBox(height: 8),
        ...h.guidance.reports.map(
          (r) => Card(
            child: ListTile(
              title: Text(_modeLabel(r.mode)),
              subtitle: Text(r.summary),
              trailing: Text(r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt),
            ),
          ),
        ),
      ],
    );
  }

  String _modeLabel(String mode) => switch (mode) {
        'weekly' => 'Weekly guidance',
        'monthly' => 'Monthly guidance',
        'exam_review' => 'Exam guidance',
        _ => mode,
      };
}
