import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../admissions/admissions_models.dart';
import '../fee_structures/finance_fee_structures_provider.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_workflow_actions.dart';
import '../integration/finance_admissions_handoff_provider.dart';
import '../widgets/finance_handoff_queue.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_fee_assignment_provider.dart';

/// FN-04 — Fee Assignment workflow.
class FinanceFeeAssignmentScreen extends ConsumerWidget {
  const FinanceFeeAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansViewState = ref.watch(financeInstallmentPlansViewStateProvider);
    final handoffQueue = ref.watch(financePendingHandoffsProvider);
    final allHandoffs = ref.watch(financeHandoffQueueProvider);
    final selectedId = ref.watch(financeSelectedHandoffIdProvider);
    final structures = ref.watch(financeFeeStructuresProvider);
    final plans = ref.watch(financeInstallmentPlansProvider);
    final generated = ref.watch(financeGeneratedAccountsProvider);
    final isMobile = AdminLayout.isMobile(context);

    FinanceHandoffQueueItem? selected;
    for (final item in allHandoffs) {
      if (item.handoff.id == selectedId) {
        selected = item;
        break;
      }
    }
    selected ??= handoffQueue.isEmpty ? null : handoffQueue.first;

    return FinanceModuleScaffold(
      screen: FinanceScreen.feeAssignment,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(title: 'Admissions handoff queue'),
          Text(
            'Assign fee structure and generate student fee account',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s2),
          const SizedBox(height: AksharaSpacing.s4),
          if (handoffQueue.isEmpty && generated.isEmpty)
            const AksharaEmptyState(
              message: 'No students awaiting fee assignment.',
              icon: Icons.assignment_outlined,
            )
          else
            FinanceAsyncBody<List<InstallmentPlan>>(
              state: plansViewState,
              loadingLabel: 'Loading fee structures and installment plans',
              emptyMessage: 'No installment plans configured.',
              emptyIcon: Icons.calendar_month_outlined,
              onRetry: () => retryFinanceFuture(
                ref,
                financeInstallmentPlansFutureProvider,
              ),
              builder: (_) {
                if (structures.isEmpty || plans.isEmpty) {
                  return const AksharaEmptyState(
                    message: 'Fee structures or installment plans unavailable.',
                    icon: Icons.receipt_long_outlined,
                  );
                }
                if (isMobile) {
                  return Column(
                    children: [
                      FinanceHandoffQueue(
                        items: allHandoffs,
                        onAssign: (item) => ref
                            .read(financeSelectedHandoffIdProvider.notifier)
                            .state = item.handoff.id,
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: AksharaSpacing.s4),
                        _AssignmentPanel(
                          item: selected,
                          structures: structures,
                          plans: plans,
                          preview: generated[selected.handoff.id],
                          onComplete: (structure, plan, transport, hostel) async {
                            try {
                              await executeAssignFeePlan(
                                ref,
                                item: selected!,
                                structure: structure,
                                plan: plan,
                                includeTransport: transport,
                                includeHostel: hostel,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Fee account created for ${selected.handoff.studentName}',
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$error'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: FinanceHandoffQueue(
                        items: allHandoffs,
                        onAssign: (item) => ref
                            .read(financeSelectedHandoffIdProvider.notifier)
                            .state = item.handoff.id,
                      ),
                    ),
                    const SizedBox(width: AksharaSpacing.s6),
                    Expanded(
                      flex: 3,
                      child: selected == null
                          ? const AksharaEmptyState(
                              message: 'Select a student from the handoff queue.',
                              icon: Icons.person_search_outlined,
                            )
                          : _AssignmentPanel(
                              item: selected,
                              structures: structures,
                              plans: plans,
                              preview: generated[selected.handoff.id],
                              onComplete: (structure, plan, transport, hostel) async {
                                try {
                                  await executeAssignFeePlan(
                                    ref,
                                    item: selected!,
                                    structure: structure,
                                    plan: plan,
                                    includeTransport: transport,
                                    includeHostel: hostel,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Fee account created'),
                                    ),
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$error')),
                                  );
                                }
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AssignmentPanel extends ConsumerStatefulWidget {
  const _AssignmentPanel({
    required this.item,
    required this.structures,
    required this.plans,
    required this.preview,
    required this.onComplete,
  });

  final FinanceHandoffQueueItem item;
  final List<FinanceFeeStructure> structures;
  final List<InstallmentPlan> plans;
  final GeneratedFeeAccountPreview? preview;
  final void Function(
    FinanceFeeStructure structure,
    InstallmentPlan plan,
    bool includeTransport,
    bool includeHostel,
  ) onComplete;

  @override
  ConsumerState<_AssignmentPanel> createState() => _AssignmentPanelState();
}

class _AssignmentPanelState extends ConsumerState<_AssignmentPanel> {
  late String _structureId;
  late String _planId;
  late bool _includeTransport;
  late bool _includeHostel;

  @override
  void initState() {
    super.initState();
    _structureId = widget.structures.isNotEmpty
        ? (widget.item.handoff.selectedFeeStructureId ??
            widget.structures.first.id)
        : '';
    _planId = widget.plans.isNotEmpty ? widget.plans.first.id : '';
    _includeTransport = widget.item.handoff.needsTransport;
    _includeHostel = widget.item.handoff.needsHostel;
  }

  @override
  void didUpdateWidget(covariant _AssignmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.handoff.id != widget.item.handoff.id) {
      if (widget.structures.isNotEmpty) {
        _structureId = widget.item.handoff.selectedFeeStructureId ??
            widget.structures.first.id;
      }
      _includeTransport = widget.item.handoff.needsTransport;
      _includeHostel = widget.item.handoff.needsHostel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final handoff = widget.item.handoff;
    final isCompleted =
        widget.item.effectiveStatus == FeeHandoffStatus.completed;
    if (widget.structures.isEmpty || widget.plans.isEmpty) {
      return const SizedBox.shrink();
    }
    final structure = widget.structures.firstWhere(
      (s) => s.id == _structureId,
      orElse: () => widget.structures.first,
    );
    final plan = widget.plans.firstWhere(
      (p) => p.id == _planId,
      orElse: () => widget.plans.first,
    );
    final preview = widget.preview;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(handoff.studentName, style: context.aksharaText.titleMedium),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${handoff.admissionNumber} · Class ${handoff.classLabel}',
              style: context.aksharaText.bodyMedium,
            ),
            Text(
              'SIS preview: ${handoff.previewStudentId}',
              style: context.aksharaText.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s6),
            if (isCompleted && preview != null) ...[
              const AksharaSectionHeader(title: 'Generated fee account'),
              const SizedBox(height: AksharaSpacing.s3),
              _PreviewCard(preview: preview),
            ] else ...[
              Material(
                child: DropdownMenu<String>(
                  key: ValueKey(_structureId),
                  initialSelection: _structureId,
                  label: const Text('Fee structure'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    for (final s in widget.structures)
                      DropdownMenuEntry(value: s.id, label: s.name),
                  ],
                  onSelected: (value) {
                    if (value != null) setState(() => _structureId = value);
                  },
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              Material(
                child: DropdownMenu<String>(
                  key: ValueKey(_planId),
                  initialSelection: _planId,
                  label: const Text('Installment plan'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    for (final p in widget.plans)
                      DropdownMenuEntry(value: p.id, label: p.label),
                  ],
                  onSelected: (value) {
                    if (value != null) setState(() => _planId = value);
                  },
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              SwitchListTile(
                title: const Text('Include transport add-on'),
                value: _includeTransport,
                onChanged: (v) => setState(() => _includeTransport = v),
              ),
              SwitchListTile(
                title: const Text('Include hostel add-on'),
                value: _includeHostel,
                onChanged: (v) => setState(() => _includeHostel = v),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              FilledButton.icon(
                onPressed: () {
                  widget.onComplete(
                    structure,
                    plan,
                    _includeTransport,
                    _includeHostel,
                  );
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Generate student fee account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final GeneratedFeeAccountPreview preview;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Generated fee account preview for ${preview.studentName}',
      child: Container(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account ${preview.accountId}', style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            Text('Structure: ${preview.feeStructureName}'),
            Text('Total due: ${preview.totalDue}'),
            Text('Plan: ${preview.installmentSummary}'),
            if (preview.addOns.isNotEmpty)
              Text('Add-ons: ${preview.addOns.join(', ')}'),
          ],
        ),
      ),
    );
  }
}
