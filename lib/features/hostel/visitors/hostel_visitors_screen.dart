import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-07 — Visitors.
class HostelVisitorsScreen extends ConsumerWidget {
  const HostelVisitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelVisitorsLoadingProvider);
    final isError = ref.watch(hostelVisitorsErrorProvider);
    final isEmpty = ref.watch(hostelVisitorsEmptyProvider);
    final data = ref.watch(hostelVisitorsProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.visitors,
      filters: const ['Today'],
      filterTrailing: AksharaManageAction(
        permission: Permission.manageHostel,
        child: OutlinedButton.icon(
          onPressed: () => showAksharaOperationalPreviewSnackBar(context, action: 'Log visitor'),
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Register visitor'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HostelVisitorsData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading visitors'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load visitors.');
    }

    if (isEmpty || data == null) {
      return const AksharaEmptyState(
        message: 'No visitor records available.',
        icon: Icons.badge_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Active visitors'),
        const SizedBox(height: AksharaSpacing.s3),
        _VisitorsTable(visitors: data.activeVisitors),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Visitor log'),
        const SizedBox(height: AksharaSpacing.s3),
        _VisitorsTable(visitors: data.visitorLog),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile)
          _QrPlaceholder(label: data.qrPlaceholderLabel)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AksharaInsightCard(
                  message:
                      'Visitor passes sync to Parent App dashboard for pickup authorization.',
                  actionLabel: 'Parent dashboard',
                  icon: Icons.qr_code_2_outlined,
                  semanticLabelPrefix: 'Parent app integration',
                  onAction: () => context.go(data.parentAppRoute),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(child: _QrPlaceholder(label: data.qrPlaceholderLabel)),
            ],
          ),
      ],
    );
  }
}

class _VisitorsTable extends StatelessWidget {
  const _VisitorsTable({required this.visitors});

  final List<HostelVisitor> visitors;

  @override
  Widget build(BuildContext context) {
    if (visitors.isEmpty) {
      return const Text('No records');
    }

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final visitor in visitors) ...[
            _VisitorCard(visitor: visitor),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Visitors table, ${visitors.length} entries',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Visitor')),
              DataColumn(label: Text('Relation')),
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Check in')),
              DataColumn(label: Text('Check out')),
              DataColumn(label: Text('Pass ID')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final visitor in visitors)
                DataRow(
                  cells: [
                    DataCell(Text(visitor.visitorName)),
                    DataCell(Text(visitor.relation)),
                    DataCell(Text(visitor.studentName)),
                    DataCell(Text(visitor.checkIn)),
                    DataCell(Text(visitor.checkOut ?? '—')),
                    DataCell(Text(visitor.passId)),
                    DataCell(_VisitorStatusChip(status: visitor.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({required this.visitor});

  final HostelVisitor visitor;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visitor.visitorName, style: text.titleSmall),
            Text(
              '${visitor.relation} of ${visitor.studentName}',
              style: text.bodyMedium,
            ),
            Text(
              '${visitor.checkIn}${visitor.checkOut != null ? ' → ${visitor.checkOut}' : ''} · ${visitor.passId}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _VisitorStatusChip(status: visitor.status),
          ],
        ),
      ),
    );
  }
}

class _VisitorStatusChip extends StatelessWidget {
  const _VisitorStatusChip({required this.status});

  final HostelVisitorStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HostelVisitorStatus.active => ('Active', KpiAccent.success),
      HostelVisitorStatus.checkedOut => ('Checked out', KpiAccent.neutral),
      HostelVisitorStatus.expired => ('Expired', KpiAccent.warning),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Visitor status: $label',
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: label,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(
                  Icons.qr_code_2_outlined,
                  size: 64,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
