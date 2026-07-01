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
import '../finance_requests.dart';
import 'finance_recovery_provider.dart';

void _showMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

List<Widget> _dialogActions(
  BuildContext context, {
  required String confirmLabel,
  required VoidCallback onConfirm,
  Key? confirmKey,
}) {
  return [
    AksharaDialogActions(
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: onConfirm,
    ),
  ];
}

const _channelLabels = <RecoveryChannel, String>{
  RecoveryChannel.call: 'Call',
  RecoveryChannel.whatsapp: 'WhatsApp',
  RecoveryChannel.sms: 'SMS',
  RecoveryChannel.visit: 'Visit',
  RecoveryChannel.email: 'Email',
  RecoveryChannel.other: 'Other',
};

const _outcomeLabels = <RecoveryOutcome, String>{
  RecoveryOutcome.reached: 'Reached',
  RecoveryOutcome.noAnswer: 'No answer',
  RecoveryOutcome.promised: 'Promised to pay',
  RecoveryOutcome.refused: 'Refused',
  RecoveryOutcome.wrongNumber: 'Wrong number',
  RecoveryOutcome.partialPaid: 'Partial paid',
  RecoveryOutcome.other: 'Other',
};

/// FIN-R4 — logs a recovery contact attempt against a defaulter.
Future<void> showLogRecoveryContactDialog(
  BuildContext context,
  WidgetRef ref, {
  required DefaulterRecord record,
}) async {
  final notesController = TextEditingController();
  var channel = RecoveryChannel.call;
  var outcome = RecoveryOutcome.reached;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Log contact — ${record.studentName}',
      icon: Icons.phone_in_talk_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          DropdownMenu<RecoveryChannel>(
            initialSelection: channel,
            label: const Text('Channel'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final entry in _channelLabels.entries)
                DropdownMenuEntry(value: entry.key, label: entry.value),
            ],
            onSelected: (value) {
              if (value != null) channel = value;
            },
          ),
          DropdownMenu<RecoveryOutcome>(
            initialSelection: outcome,
            label: const Text('Outcome'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final entry in _outcomeLabels.entries)
                DropdownMenuEntry(value: entry.key, label: entry.value),
            ],
            onSelected: (value) {
              if (value != null) outcome = value;
            },
          ),
          AksharaFormField(
            label: 'Notes',
            controller: notesController,
            hint: 'What was discussed',
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Log contact',
        confirmKey: QaTestKeys.financeLogContactSubmitButton,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final contact = await ref.read(logRecoveryContactProvider.notifier).execute(
          LogRecoveryContactRequest(
            studentId: record.id,
            feeAccountId: record.feeAccountId,
            channel: channel,
            outcome: outcome,
            notes: notesController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeLogContactSuccessSnackbar,
        content: Text(
          contact == null
              ? 'Contact could not be logged'
              : 'Contact logged for ${record.studentName}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-R3 — records a student's promise to pay.
Future<void> showCreatePromiseToPayDialog(
  BuildContext context,
  WidgetRef ref, {
  required DefaulterRecord record,
}) async {
  final amountController = TextEditingController(text: record.overdueAmount);
  final notesController = TextEditingController();
  var promiseDate = DateTime.now().add(const Duration(days: 7));

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AksharaAlertDialog(
        title: 'Promise to pay — ${record.studentName}',
        icon: Icons.event_available_outlined,
        scrollable: true,
        content: AksharaDialogFormBody(
          children: [
            AksharaFormField(
              label: 'Amount',
              controller: amountController,
              required: true,
              keyboardType: TextInputType.number,
              hint: 'Amount the parent promised',
            ),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Promise date',
                border: OutlineInputBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDate(promiseDate)),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: promiseDate,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 1)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => promiseDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: const Text('Pick'),
                  ),
                ],
              ),
            ),
            AksharaFormField(
              label: 'Notes',
              controller: notesController,
              hint: 'Optional context',
            ),
          ],
        ),
        actions: _dialogActions(
          context,
          confirmLabel: 'Record promise',
          confirmKey: QaTestKeys.financePromiseToPaySubmitButton,
          onConfirm: () {
            if (amountController.text.trim().isEmpty) return;
            Navigator.of(context).pop(true);
          },
        ),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final promise =
        await ref.read(createPromiseToPayProvider.notifier).execute(
              CreatePromiseToPayRequest(
                studentId: record.id,
                feeAccountId: record.feeAccountId,
                amount: amountController.text.trim(),
                promiseDate: _isoDate(promiseDate),
                notes: notesController.text.trim(),
              ),
            );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financePromiseToPaySuccessSnackbar,
        content: Text(
          promise == null
              ? 'Promise could not be recorded'
              : 'Promise recorded for ${record.studentName} '
                  '(${promise.promiseDate})',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-R3 — resolves a pending promise (kept / broken / cancelled).
Future<void> resolvePromise(
  BuildContext context,
  WidgetRef ref, {
  required PromiseToPay promise,
  required PromiseToPayStatus status,
}) async {
  try {
    await ref.read(resolvePromiseToPayProvider.notifier).execute(
          promiseId: promise.id,
          status: status,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Promise for ${promise.studentName} marked ${status.name}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-8 — exports class-wise dues (Class, Students, Total Outstanding) as a
/// grid CSV, grouped from the loaded defaulter records.
Future<void> exportClassWiseDues(
  BuildContext context,
  WidgetRef ref, {
  required List<DefaulterRecord> defaulters,
}) async {
  if (defaulters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No defaulters to export')),
    );
    return;
  }

  final byClass = <String, List<DefaulterRecord>>{};
  for (final record in defaulters) {
    final key = record.classLabel.isEmpty ? 'Unassigned' : record.classLabel;
    byClass.putIfAbsent(key, () => []).add(record);
  }

  final classRows = <List<String>>[
    for (final entry in _sortedClassEntries(byClass))
      [
        entry.key,
        '${entry.value.length}',
        _sumOutstanding(entry.value),
      ],
  ];

  try {
    await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
      filename: 'class_wise_dues',
      headers: const ['Class', 'Students', 'Total Outstanding'],
      rows: classRows,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class-wise dues exported')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// FIN-8 — exports the full defaulter list as a grid CSV.
Future<void> exportDefaulterList(
  BuildContext context,
  WidgetRef ref, {
  required List<DefaulterRecord> defaulters,
}) async {
  if (defaulters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No defaulters to export')),
    );
    return;
  }

  final rows = <List<String>>[
    for (final record in defaulters)
      [
        record.studentName,
        record.admissionNumber,
        record.classLabel,
        record.overdueAmount,
        '${record.daysOverdue}',
        record.lastContact,
      ],
  ];

  try {
    await ref.read(aksharaReportExportServiceProvider).shareGridCsv(
      filename: 'defaulter_list',
      headers: const [
        'Student',
        'Admission No.',
        'Class',
        'Outstanding',
        'Days Overdue',
        'Last Contact',
      ],
      rows: rows,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defaulter list exported')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

List<MapEntry<String, List<DefaulterRecord>>> _sortedClassEntries(
  Map<String, List<DefaulterRecord>> byClass,
) {
  final entries = byClass.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries;
}

String _sumOutstanding(List<DefaulterRecord> records) {
  final total = records.fold<double>(
    0,
    (sum, r) => sum + _parseAmount(r.overdueAmount),
  );
  return '₹${total.round()}';
}

double _parseAmount(String value) =>
    double.tryParse(value.replaceAll(RegExp(r'[₹,\s]'), '')) ?? 0;

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.year}';

String _isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
