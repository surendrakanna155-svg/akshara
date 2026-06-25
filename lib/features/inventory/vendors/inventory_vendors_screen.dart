import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/widgets/whatsapp_contact_button.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../widgets/inventory_module_scaffold.dart';

/// INV-07 — Vendors.
class InventoryVendorsScreen extends ConsumerWidget {
  const InventoryVendorsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Pending',
    'Inactive',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryVendorsLoadingProvider);
    final isError = ref.watch(inventoryVendorsErrorProvider);
    final isEmpty = ref.watch(inventoryVendorsEmptyProvider);
    final vendors = ref.watch(inventoryFilteredVendorsProvider);
    final filterIndex = ref.watch(inventoryVendorsFilterProvider);
    final pageResult = ref.watch(inventoryVendorsPageResultProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.vendors,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryVendorsFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        vendors: vendors,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<InventoryVendor> vendors,
    required PaginatedResult<InventoryVendor>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading vendors'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load vendors.');
    }

    if (isEmpty || vendors.isEmpty) {
      return const AksharaEmptyState(
        message: 'No vendors match the selected filters.',
        icon: Icons.store_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Vendor directory'),
        const SizedBox(height: AksharaSpacing.s3),
        _VendorTable(vendors: vendors),
        AksharaPaginatedListFooter<InventoryVendor>(
          result: pageResult,
          pageProvider: inventoryVendorsPageProvider,
        ),
      ],
    );
  }
}

class _VendorTable extends StatelessWidget {
  const _VendorTable({required this.vendors});

  final List<InventoryVendor> vendors;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final vendor in vendors) ...[
            _VendorCard(vendor: vendor),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Vendor directory, ${vendors.length} vendors',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: Text('GST')),
              DataColumn(label: Text('Active POs')),
              DataColumn(label: Text('Total spend')),
              DataColumn(label: Text('Finance ID')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final vendor in vendors)
                DataRow(
                  cells: [
                    DataCell(Text(vendor.name)),
                    DataCell(Text(vendor.category)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(vendor.contactPerson),
                        WhatsAppContactButton(
                          phone: vendor.phone,
                          style: WhatsAppButtonStyle.icon,
                          label: 'WhatsApp ${vendor.contactPerson}',
                          message: _vendorMessage(vendor),
                        ),
                      ],
                    )),
                    DataCell(Text(vendor.gstNumber)),
                    DataCell(Text('${vendor.activeOrders}')),
                    DataCell(Text(vendor.totalSpend)),
                    DataCell(Text(vendor.financeVendorId)),
                    DataCell(_VendorStatusChip(status: vendor.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor});

  final InventoryVendor vendor;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Vendor ${vendor.name}, ${vendor.category}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vendor.name, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${vendor.category} · ${vendor.contactPerson}',
                style: text.bodyMedium,
              ),
              Text(
                '${vendor.totalSpend} · ${vendor.financeVendorId}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _VendorStatusChip(status: vendor.status),
                  WhatsAppContactButton(
                    phone: vendor.phone,
                    style: WhatsAppButtonStyle.text,
                    label: 'WhatsApp',
                    message: _vendorMessage(vendor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _vendorMessage(InventoryVendor vendor) =>
    'Hello ${vendor.contactPerson}, this is from the school procurement office '
    'regarding ${vendor.name}. ';

class _VendorStatusChip extends StatelessWidget {
  const _VendorStatusChip({required this.status});

  final InventoryVendorStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      InventoryVendorStatus.active => ('Active', KpiAccent.success),
      InventoryVendorStatus.pending => ('Pending', KpiAccent.warning),
      InventoryVendorStatus.inactive => ('Inactive', KpiAccent.neutral),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Vendor status: $label',
    );
  }
}
