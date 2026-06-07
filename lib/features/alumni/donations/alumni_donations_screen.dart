import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-05 — Donations.
class AlumniDonationsScreen extends ConsumerWidget {
  const AlumniDonationsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Received',
    'Pledged',
    'Pending',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniDonationsLoadingProvider);
    final isError = ref.watch(alumniDonationsErrorProvider);
    final isEmpty = ref.watch(alumniDonationsEmptyProvider);
    final donations = ref.watch(alumniFilteredDonationsProvider);
    final filterIndex = ref.watch(alumniDonationsFilterProvider);

    return AlumniModuleScaffold(
      screen: AlumniScreen.donations,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(alumniDonationsFilterProvider.notifier).state = index,
      filterTrailing: OutlinedButton.icon(
        onPressed: () => context.go(RouteNames.financeCollections),
        icon: const Icon(Icons.account_balance_outlined, size: 18),
        label: const Text('Finance ledger'),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        donations: donations,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<AlumniDonation> donations,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading alumni donations'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load alumni donations.',
      );
    }

    if (isEmpty || donations.isEmpty) {
      return const AksharaEmptyState(
        message: 'No donations match the selected filters.',
        icon: Icons.volunteer_activism_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Donation ledger'),
        const SizedBox(height: AksharaSpacing.s3),
        _DonationsTable(donations: donations),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Donations post to Finance FN-05 collections. Receipt IDs link to finance collection detail.',
          actionLabel: 'View collections',
          icon: Icons.receipt_long_outlined,
          semanticLabelPrefix: 'Finance donations integration',
          onAction: () => context.go(RouteNames.financeCollections),
        ),
      ],
    );
  }
}

class _DonationsTable extends StatelessWidget {
  const _DonationsTable({required this.donations});

  final List<AlumniDonation> donations;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final donation in donations) ...[
            _DonationCard(donation: donation),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Donations table, ${donations.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Alumni')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Campaign')),
              DataColumn(label: Text('Receipt')),
              DataColumn(label: Text('Mode')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final donation in donations)
                DataRow(
                  onSelectChanged: (_) => context.go(
                    RouteNames.alumniProfileDetail(donation.alumniId),
                  ),
                  cells: [
                    DataCell(Text(donation.alumniName)),
                    DataCell(Text(donation.amount)),
                    DataCell(Text(donation.date)),
                    DataCell(Text(donation.campaign)),
                    DataCell(Text(donation.financeReceiptId)),
                    DataCell(Text(donation.paymentMode)),
                    DataCell(_DonationStatusChip(status: donation.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.donation});

  final AlumniDonation donation;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Donation ${donation.amount} from ${donation.alumniName}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(donation.alumniName, style: text.titleSmall),
                  ),
                  _DonationStatusChip(status: donation.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${donation.amount} · ${donation.campaign}',
                style: text.bodyMedium,
              ),
              Text(
                '${donation.date} · ${donation.financeReceiptId}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationStatusChip extends StatelessWidget {
  const _DonationStatusChip({required this.status});

  final AlumniDonationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AlumniDonationStatus.received => ('Received', KpiAccent.success),
      AlumniDonationStatus.pledged => ('Pledged', KpiAccent.primary),
      AlumniDonationStatus.pending => ('Pending', KpiAccent.warning),
      AlumniDonationStatus.refunded => ('Refunded', KpiAccent.error),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
