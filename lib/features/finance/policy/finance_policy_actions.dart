import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/forms/akshara_form_field.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../shared/widgets/akshara_motion.dart';
import '../finance_models.dart';
import 'finance_policy_provider.dart';

void _showMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

/// FIN-D5 — accrues late fees on eligible outstanding invoices and reports the
/// count + total that were charged.
Future<void> accrueLateFees(BuildContext context, WidgetRef ref) async {
  try {
    final result =
        await ref.read(accrueLateFeesProvider.notifier).execute();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeAccrueLateFeesSnackbar,
        content: Text(
          result == null
              ? 'Late fee accrual did not run'
              : 'Accrued late fee on ${result.accruedCount} '
                  '${result.accruedCount == 1 ? 'invoice' : 'invoices'} '
                  '(₹${result.totalLateFee})',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-D3 — exports the cancelled-collections register as a grid CSV.
Future<void> exportCancelledRegister(
  BuildContext context,
  WidgetRef ref,
) async {
  final List<CancelledCollection> cancelled;
  try {
    cancelled =
        await ref.read(financeCancelledCollectionsFutureProvider.future);
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
    return;
  }
  if (!context.mounted) return;
  if (cancelled.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No cancelled collections to export')),
    );
    return;
  }

  final rows = <List<String>>[
    for (final c in cancelled)
      [
        c.receiptNumber,
        c.studentName,
        c.admissionNumber,
        c.classLabel,
        c.amount,
        c.mode,
        c.collectedAt,
        c.reason,
        c.cancelledByName,
        c.cancelledAt,
      ],
  ];

  try {
    await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
      filename: 'cancelled_collections_register',
      headers: const [
        'Receipt',
        'Student',
        'Admission',
        'Class',
        'Amount',
        'Mode',
        'Collected',
        'Reason',
        'Cancelled By',
        'Cancelled At',
      ],
      rows: rows,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cancelled register exported (${rows.length} rows)'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-D1 — closes the current day (default today).
Future<void> closeDay(BuildContext context, WidgetRef ref, {String? date}) async {
  try {
    final entry =
        await ref.read(closeDayProvider.notifier).execute(date: date);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeDayCloseSnackbar,
        content: Text(
          entry == null ? 'Day could not be closed' : 'Day closed — ${entry.closeDate}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-D1 — reopens a previously-closed day.
Future<void> reopenDay(
  BuildContext context,
  WidgetRef ref, {
  required String date,
}) async {
  try {
    final entry = await ref.read(reopenDayProvider.notifier).execute(date: date);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeDayCloseSnackbar,
        content: Text(
          entry == null ? 'Day could not be reopened' : 'Day reopened — $date',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-D5 — prompts for a mandatory reason then waives an invoice's late fee.
Future<void> showWaiveLateFeeDialog(
  BuildContext context,
  WidgetRef ref, {
  required String invoiceId,
  required String invoiceNumber,
  required String lateFeeAmount,
}) async {
  final reasonController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Waive late fee — $invoiceNumber',
      icon: Icons.money_off_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          Text('Late fee currently accrued: ₹$lateFeeAmount'),
          const SizedBox(height: 12),
          AksharaFormField(
            label: 'Reason',
            controller: reasonController,
            required: true,
            hint: 'Why is this late fee being waived?',
          ),
        ],
      ),
      actions: [
        AksharaDialogActions(
          confirmLabel: 'Waive late fee',
          confirmKey: QaTestKeys.financeWaiveLateFeeConfirmButton,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () {
            // A waive reason is mandatory — do not submit an empty reason.
            if (reasonController.text.trim().isEmpty) return;
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final invoice = await ref.read(waiveLateFeeProvider.notifier).execute(
          invoiceId: invoiceId,
          reason: reasonController.text.trim(),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeWaiveLateFeeSnackbar,
        content: Text(
          invoice == null
              ? 'Late fee could not be waived'
              : 'Late fee waived on $invoiceNumber',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}
