import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import 'finance_journey_context_provider.dart';
import 'fee_assignment/finance_fee_assignment_provider.dart';
import 'finance_models.dart';
import 'finance_mutations_provider.dart';
import 'finance_requests.dart';
import 'integration/finance_admissions_handoff_provider.dart';

void _showMutationError(BuildContext context, Object error) {
  final failure = error is ApiFailureException
      ? error.failure
      : apiFailureMapper.fromException(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}

Future<void> showCreateFeeStructureDialog(
  BuildContext context,
  WidgetRef ref, {
  String academicYear = '2026-27',
}) async {
  final nameController = TextEditingController(text: 'New fee structure');
  final totalController = TextEditingController(text: '₹1,85,000');
  final classRangeController = TextEditingController(text: 'Nursery – 12');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create fee structure'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: totalController,
              decoration: const InputDecoration(labelText: 'Annual total'),
            ),
            TextField(
              controller: classRangeController,
              decoration: const InputDecoration(labelText: 'Class range'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(createFeeStructureProvider.notifier).execute(
          CreateFeeStructureRequest(
            name: nameController.text.trim(),
            academicYear: academicYear,
            totalAnnual: totalController.text.trim(),
            classRange: classRangeController.text.trim(),
            categories: const [
              FeeCategoryLine(
                category: FeeStructureCategory.tuition,
                label: 'Tuition',
                amount: '₹1,45,000',
              ),
            ],
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fee structure created')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> showEditFeeStructureDialog(
  BuildContext context,
  WidgetRef ref, {
  required FinanceFeeStructure structure,
}) async {
  final nameController = TextEditingController(text: structure.name);
  final totalController = TextEditingController(text: structure.totalAnnual);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit fee structure'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: totalController,
            decoration: const InputDecoration(labelText: 'Annual total'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(updateFeeStructureProvider.notifier).execute(
          feeStructureId: structure.id,
          request: UpdateFeeStructureRequest(
            name: nameController.text.trim(),
            totalAnnual: totalController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fee structure updated')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> executeAssignFeePlan(
  WidgetRef ref, {
  required FinanceHandoffQueueItem item,
  required FinanceFeeStructure structure,
  required InstallmentPlan plan,
  required bool includeTransport,
  required bool includeHostel,
}) async {
  final handoff = item.handoff;
  final preview = buildFeeAccountPreview(
    handoffId: handoff.id,
    studentName: handoff.studentName,
    admissionNumber: handoff.admissionNumber,
    structure: structure,
    plan: plan,
    includeTransport: includeTransport,
    includeHostel: includeHostel,
  );

  await ref.read(assignFeePlanProvider.notifier).execute(
        AssignFeePlanRequest(
          handoffId: handoff.id,
          feeStructureId: structure.id,
          installmentPlanId: plan.id,
          includeTransport: includeTransport,
          includeHostel: includeHostel,
          studentName: handoff.studentName,
          admissionNumber: handoff.admissionNumber,
          classLabel: handoff.classLabel,
        ),
      );

  completeFinanceHandoffAssignment(
    ref,
    handoffId: handoff.id,
    preview: preview,
  );
}

Future<void> approveSelectedRefund(
  BuildContext context,
  WidgetRef ref, {
  required RefundRequest refund,
}) async {
  try {
    await ref.read(approveRefundProvider.notifier).execute(refundId: refund.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refund approved for ${refund.studentName}')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> rejectSelectedRefund(
  BuildContext context,
  WidgetRef ref, {
  required RefundRequest refund,
}) async {
  try {
    await ref.read(rejectRefundProvider.notifier).execute(refundId: refund.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refund rejected for ${refund.studentName}')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> showCreateScholarshipDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final discountController = TextEditingController(text: '10%');
  final eligibilityController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create scholarship'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Scholarship name'),
          ),
          TextField(
            controller: discountController,
            decoration: const InputDecoration(labelText: 'Max discount'),
          ),
          TextField(
            controller: eligibilityController,
            decoration: const InputDecoration(labelText: 'Eligibility'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(createScholarshipProvider.notifier).execute(
          CreateScholarshipRequest(
            name: nameController.text.trim(),
            type: ScholarshipType.merit,
            maxDiscount: discountController.text.trim(),
            eligibility: eligibilityController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scholarship created')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> showEditFinanceSettingDialog(
  BuildContext context,
  WidgetRef ref, {
  required FinanceSettingItem item,
  required String sectionId,
}) async {
  final valueController = TextEditingController(text: item.value);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Edit ${item.label}'),
      content: TextField(
        controller: valueController,
        decoration: InputDecoration(labelText: item.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(updateFinanceSettingsProvider.notifier).execute(
          UpdateFinanceSettingsRequest(
            updates: [
              FinanceSettingUpdate(
                sectionId: sectionId,
                itemId: item.id,
                value: valueController.text.trim(),
              ),
            ],
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.label} updated')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> showRecordCollectionDialog(
  BuildContext context,
  WidgetRef ref, {
  String defaultInvoiceId = 'inv_1',
  String defaultAmount = '5000',
}) async {
  final journeyInvoice = ref.read(financeLastInvoiceIdProvider);
  final invoiceController = TextEditingController(
    text: journeyInvoice ?? defaultInvoiceId,
  );
  final amountController = TextEditingController(text: defaultAmount);
  var paymentMethod = 'UPI';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Record collection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: QaTestKeys.financeCollectionInvoiceField,
              controller: invoiceController,
              decoration: const InputDecoration(labelText: 'Invoice ID'),
            ),
            TextField(
              key: QaTestKeys.financeCollectionAmountField,
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount collected'),
              keyboardType: TextInputType.number,
            ),
            DropdownMenu<String>(
              initialSelection: paymentMethod,
              label: const Text('Payment method'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'Cash', label: 'Cash'),
                DropdownMenuEntry(value: 'UPI', label: 'UPI'),
                DropdownMenuEntry(value: 'Card', label: 'Card'),
              ],
              onSelected: (value) {
                if (value != null) paymentMethod = value;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.financeCollectionSubmitButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Record payment'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final result = await ref.read(createCollectionProvider.notifier).execute(
          CreateCollectionRequest(
            invoiceId: invoiceController.text.trim(),
            amountCollected: amountController.text.trim(),
            paymentMethod: paymentMethod,
            collectionDate: 'Today',
          ),
        );
    if (!context.mounted || result == null) return;
    ref.read(financeLastReceiptNumberProvider.notifier).state =
        result.receiptNumber;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeCollectionSuccessSnackbar,
        content: Text('Receipt ${result.receiptNumber} recorded'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

void navigateToQrPaymentScreen(
  BuildContext context, {
  required String invoiceId,
  required String amount,
}) {
  final uri = Uri(
    path: RouteNames.financeQrPayment,
    queryParameters: {
      'invoiceId': invoiceId,
      'amount': amount,
    },
  );
  context.push(uri.toString());
}

Future<void> executeIssueInvoice(
  BuildContext context,
  WidgetRef ref, {
  required String invoiceId,
}) async {
  try {
    final invoice = await ref.read(issueInvoiceProvider.notifier).execute(
          invoiceId: invoiceId,
        );
    if (!context.mounted || invoice == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeInvoiceIssuedSnackbar,
        content: Text('Invoice ${invoice.invoiceNumber} issued'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> executeCancelInvoice(
  BuildContext context,
  WidgetRef ref, {
  required String invoiceId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel invoice'),
      content: Text('Cancel invoice $invoiceId? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep'),
        ),
        FilledButton(
          key: QaTestKeys.financeCancelInvoiceConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cancel invoice'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final invoice = await ref.read(cancelInvoiceProvider.notifier).execute(
          invoiceId: invoiceId,
        );
    if (!context.mounted || invoice == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeInvoiceCancelledSnackbar,
        content: Text('Invoice ${invoice.invoiceNumber} cancelled'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> executeCancelCollection(
  BuildContext context,
  WidgetRef ref, {
  required String collectionId,
  required String receiptNumber,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel collection'),
      content: Text(
        'Cancel receipt $receiptNumber? The payment will be marked refunded.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep'),
        ),
        FilledButton(
          key: QaTestKeys.financeCancelCollectionConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cancel collection'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final result = await ref.read(cancelCollectionProvider.notifier).execute(
          collectionId: collectionId,
        );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeCollectionCancelledSnackbar,
        content: Text('Collection ${result.receiptNumber} cancelled'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}
