import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../parent_active_child_provider.dart';
import '../receipts/parent_receipts_provider.dart';
import '../receipts/receipt_models.dart';
import 'fee_certificate_models.dart';
import 'fees_provider.dart';
import 'parent_fee_certificate_pdf_service.dart';
import 'parent_year_statement_exporter.dart';

/// Single payment history row (used in list / bottom sheet).
class PaymentHistoryCard extends StatelessWidget {
  const PaymentHistoryCard({
    super.key,
    required this.item,
    this.onTap,
    this.showDivider = true,
  });

  final PaymentHistoryItem item;
  final VoidCallback? onTap;
  final bool showDivider;

  static const double rowHeight = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final statusColor = item.isSuccess ? ext.success : colors.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          label: '${item.title}, ${item.dateLabel}, ${formatInr(item.amount)}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.isSuccess
                              ? ext.successContainer
                              : colors.errorContainer,
                          borderRadius: AksharaRadius.chip,
                        ),
                        child: Icon(
                          item.isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: statusColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AksharaSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              style: text.bodyMedium.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.dateLabel,
                              style: text.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formatInr(item.amount),
                            style: text.titleSmall.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            item.statusLabel,
                            style: text.labelSmall.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}

/// Bottom sheet listing all payment history entries.
///
/// PAR-4 — the header carries an "Export year statement" action that builds a
/// CSV or PDF fee statement from the active child's receipts (own-child scoped
/// via [parentReceiptsFutureProvider]).
class PaymentHistorySheet extends ConsumerWidget {
  const PaymentHistorySheet({
    super.key,
    required this.items,
    this.onItemTap,
  });

  final List<PaymentHistoryItem> items;
  final void Function(PaymentHistoryItem item)? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AksharaSpacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment history',
                    style: text.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
                TextButton.icon(
                  key: QaTestKeys.parentFeesExportStatementButton,
                  onPressed: () => _exportStatement(context, ref),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export statement'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.s4,
              0,
              AksharaSpacing.s4,
              AksharaSpacing.s2,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: QaTestKeys.parentFeeCertificateButton,
                onPressed: () => _downloadFeeCertificate(context, ref),
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: const Text('Fee payment certificate (80C)'),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: colors.outlineVariant,
              ),
              itemBuilder: (context, index) {
                return PaymentHistoryCard(
                  item: items[index],
                  showDivider: false,
                  onTap: onItemTap == null
                      ? null
                      : () => onItemTap!(items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// PAR-4 — lets the parent pick CSV or PDF, then exports the year statement
  /// built from the active child's receipts. Own-child scoped: the receipts
  /// come from the active-child-scoped [parentReceiptsFutureProvider].
  Future<void> _exportStatement(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final exporter = ref.read(parentYearStatementExporterProvider);
    final childName = ref.read(parentActiveChildProvider)?.name ?? '';
    // Own-child receipts (the fees screen already has these loaded).
    final List<FeeReceipt> receipts =
        ref.read(parentReceiptsFutureProvider).valueOrNull ?? const [];

    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: QaTestKeys.parentFeesExportCsvButton,
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export as CSV'),
              onTap: () => Navigator.of(context).pop('csv'),
            ),
            ListTile(
              key: QaTestKeys.parentFeesExportPdfButton,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
          ],
        ),
      ),
    );
    if (format == null) return;

    try {
      if (format == 'csv') {
        await exporter.shareCsv(receipts: receipts, childName: childName);
      } else {
        await exporter.sharePdf(receipts: receipts, childName: childName);
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }

  /// PAR-D3 — the current Indian financial year (Apr 1 → Mar 31) label, e.g.
  /// `2025-2026`. Matches the backend's `currentFinancialYear` convention.
  static String currentFinancialYearLabel([DateTime? now]) {
    final today = now ?? DateTime.now();
    final startYear = today.month >= 4 ? today.year : today.year - 1;
    return '$startYear-${startYear + 1}';
  }

  /// The most recent financial years offered in the certificate year picker
  /// (current FY first).
  static List<String> financialYearOptions([DateTime? now]) {
    final current = currentFinancialYearLabel(now);
    final startYear = int.parse(current.split('-').first);
    return [for (var i = 0; i < 4; i++) '${startYear - i}-${startYear - i + 1}'];
  }

  /// PAR-D3 — picks an academic year (default current FY), fetches the active
  /// child's 80C fee-payment certificate (own-child scoped server-side), and
  /// renders/shares the PDF. Honest empty message when nothing was paid.
  Future<void> _downloadFeeCertificate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final year = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          key: QaTestKeys.parentFeeCertificateYearPicker,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: Text(
                'Select academic year',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final option in financialYearOptions())
              ListTile(
                key: QaTestKeys.parentFeeCertificateYearOption(option),
                leading: const Icon(Icons.event_outlined),
                title: Text(option),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (year == null) return;

    final query = ref.read(parentRepositoryQueryProvider);
    final repository = ref.read(parentRepositoryProvider);
    final pdfService = ref.read(parentFeeCertificatePdfServiceProvider);

    try {
      final FeeCertificateData certificate = await repository.getFeeCertificate(
        query: query,
        academicYear: year,
      );

      if (certificate.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            key: QaTestKeys.parentFeeCertificateEmptyMessage,
            content: Text('No payments recorded for $year'),
          ),
        );
        return;
      }

      final bytes = await pdfService.buildCertificatePdf(certificate);
      await pdfService.shareCertificate(
        bytes: bytes,
        academicYear: certificate.academicYear,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }
}
