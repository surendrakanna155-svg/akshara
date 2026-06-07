import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../widgets/control_center_segment_panel.dart';
import '../widgets/control_center_trend_chart.dart';

/// ACC-04 — Platform Billing.
class ControlCenterBillingScreen extends ConsumerWidget {
  const ControlCenterBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterBillingLoadingProvider);
    final isError = ref.watch(controlCenterBillingErrorProvider);
    final data = ref.watch(controlCenterBillingProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.billing,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required ControlCenterBillingData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading billing data'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load platform billing.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Billing data is not available.',
      );
    }

    final text = context.aksharaText;
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Platform revenue'),
        Text(
          'MRR ₹${data.mrrLakhs}L · ARR ₹${data.arrLakhs}L · Outstanding ₹${data.outstandingLakhs}L',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          ControlCenterTrendChart(
            title: 'Revenue trend',
            points: data.revenueTrend,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          ControlCenterSegmentPanel(
            title: 'Revenue by plan',
            segments: data.revenueByPlan,
            height: 220,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ControlCenterTrendChart(
                  title: 'Revenue trend',
                  points: data.revenueTrend,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: ControlCenterSegmentPanel(
                  title: 'Revenue by plan',
                  segments: data.revenueByPlan,
                  height: 280,
                ),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Recent invoices'),
        const SizedBox(height: AksharaSpacing.s3),
        _InvoicesTable(invoices: data.invoices),
      ],
    );
  }
}

class _InvoicesTable extends StatelessWidget {
  const _InvoicesTable({required this.invoices});

  final List<BillingInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Invoices table, ${invoices.length} invoices',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Invoice')),
              DataColumn(label: Text('School')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final invoice in invoices)
                DataRow(
                  cells: [
                    DataCell(Text(invoice.id)),
                    DataCell(Text(invoice.schoolName)),
                    DataCell(Text('₹${invoice.amountLakhs}L')),
                    DataCell(Text(invoice.dueDate)),
                    DataCell(Text(invoice.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
