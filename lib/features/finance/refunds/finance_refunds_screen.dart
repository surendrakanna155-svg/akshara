import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_models.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_refunds_provider.dart';

/// FN-08 — Refund requests queue and approval.
class FinanceRefundsScreen extends ConsumerWidget {
  const FinanceRefundsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Approved',
    'Processed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(financeRefundsLoadingProvider);
    final isError = ref.watch(financeRefundsErrorProvider);
    final isEmpty = ref.watch(financeRefundsEmptyProvider);
    final refunds = ref.watch(financeFilteredRefundsProvider);
    final selected = ref.watch(financeSelectedRefundProvider);
    final filterIndex = ref.watch(financeRefundsFilterProvider);
    final isMobile = AdminLayout.isMobile(context);

    return FinanceModuleScaffold(
      screen: FinanceScreen.refunds,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(financeRefundsFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        refunds: refunds,
        selected: selected,
        isMobile: isMobile,
        onSelect: (id) =>
            ref.read(financeSelectedRefundIdProvider.notifier).state = id,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<RefundRequest> refunds,
    required RefundRequest? selected,
    required bool isMobile,
    required ValueChanged<String> onSelect,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading refund requests',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load refund requests.',
      );
    }

    if (isEmpty || refunds.isEmpty) {
      return const AksharaEmptyState(
        message: 'No refund requests for the selected filters.',
        icon: Icons.currency_exchange_outlined,
      );
    }

    if (isMobile) {
      return Column(
        children: [
          for (final refund in refunds) ...[
            _RefundListTile(
              refund: refund,
              selected: refund.id == selected?.id,
              onTap: () => onSelect(refund.id),
            ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
          if (selected != null) ...[
            const SizedBox(height: AksharaSpacing.s4),
            _RefundDetailPanel(refund: selected),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Semantics(
            container: true,
            label: 'Refund request queue, ${refunds.length} items',
            child: Column(
              children: [
                for (final refund in refunds)
                  _RefundListTile(
                    refund: refund,
                    selected: refund.id == selected?.id,
                    onTap: () => onSelect(refund.id),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AksharaSpacing.s6),
        Expanded(
          flex: 3,
          child: selected == null
              ? const AksharaEmptyState(
                  message: 'Select a refund request.',
                  icon: Icons.currency_exchange_outlined,
                )
              : _RefundDetailPanel(refund: selected),
        ),
      ],
    );
  }
}

class _RefundListTile extends StatelessWidget {
  const _RefundListTile({
    required this.refund,
    required this.selected,
    required this.onTap,
  });

  final RefundRequest refund;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      selected: selected,
      label: '${refund.studentName}, ${refund.amount}, ${refund.status.name}',
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(refund.studentName, style: text.titleSmall),
                      Text(
                        '${refund.admissionNumber} · ${refund.amount}',
                        style: text.bodySmall,
                      ),
                      Text(refund.requestedAt, style: text.bodySmall),
                    ],
                  ),
                ),
                _RefundStatusChip(status: refund.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RefundDetailPanel extends StatelessWidget {
  const _RefundDetailPanel({required this.refund});

  final RefundRequest refund;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Refund detail for ${refund.studentName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(title: refund.studentName),
          Text(
            '${refund.admissionNumber} · Class ${refund.classLabel}',
            style: text.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _RefundStatusChip(status: refund.status),
          const SizedBox(height: AksharaSpacing.s4),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Refund amount', style: text.titleSmall),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(refund.amount, style: text.headlineSmall),
                  const SizedBox(height: AksharaSpacing.s4),
                  Text('Reason', style: text.titleSmall),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(refund.reason),
                  const SizedBox(height: AksharaSpacing.s4),
                  Text('Original receipt', style: text.titleSmall),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(refund.originalReceipt),
                  const SizedBox(height: AksharaSpacing.s4),
                  Text('Approver', style: text.titleSmall),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(refund.approver),
                  const SizedBox(height: AksharaSpacing.s4),
                  Text('Requested', style: text.titleSmall),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(refund.requestedAt),
                ],
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefundStatusChip extends StatelessWidget {
  const _RefundStatusChip({required this.status});

  final RefundStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      RefundStatus.pending => ('Pending', KpiAccent.warning),
      RefundStatus.approved => ('Approved', KpiAccent.primary),
      RefundStatus.rejected => ('Rejected', KpiAccent.error),
      RefundStatus.processed => ('Processed', KpiAccent.success),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}
