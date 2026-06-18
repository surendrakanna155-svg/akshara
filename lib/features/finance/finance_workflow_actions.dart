import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/finance_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
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

List<Widget> _dialogActions(
  BuildContext context, {
  required String confirmLabel,
  required VoidCallback onConfirm,
  String cancelLabel = 'Cancel',
  Key? confirmKey,
  bool destructive = false,
}) {
  return [
    AksharaDialogActions(
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
      destructive: destructive,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: onConfirm,
    ),
  ];
}

Future<void> showCreateFeeStructureDialog(
  BuildContext context,
  WidgetRef ref, {
  String academicYear = '2026-27',
}) async {
  final nameController = TextEditingController(text: 'New fee structure');
  final totalController = TextEditingController(text: '₹1,85,000');
  final classRangeController = TextEditingController(text: 'Nursery – 12');

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Create fee structure',
      icon: Icons.receipt_long_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Name',
            controller: nameController,
          ),
          AksharaFormField(
            label: 'Annual total',
            controller: totalController,
          ),
          AksharaFormField(
            label: 'Class range',
            controller: classRangeController,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Create',
        confirmKey: QaTestKeys.financeCreateFeeStructureSubmitButton,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final created = await ref.read(createFeeStructureProvider.notifier).execute(
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
    final approvalRequired = ref.read(financeApprovalRequiredProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == null
              ? 'Fee structure could not be created'
              : approvalRequired
                  ? 'Fee structure created and submitted for principal approval (${created.id})'
                  : 'Fee structure created (${created.id})',
        ),
      ),
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

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Edit fee structure',
      icon: Icons.edit_outlined,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Name',
            controller: nameController,
          ),
          AksharaFormField(
            label: 'Annual total',
            controller: totalController,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Save',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
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

Future<void> showCreateRefundDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final feeAccountController = TextEditingController(text: 'acct_1');
  final studentNameController = TextEditingController(text: 'Arjun Patel');
  final admissionController = TextEditingController(text: 'ADM-2026-0138');
  final classController = TextEditingController(text: '10');
  final amountController = TextEditingController(text: '₹5,000');
  final reasonController =
      TextEditingController(text: 'Fee adjustment — duplicate payment');
  final receiptController = TextEditingController(text: 'RCP-2026-0142');

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Create refund request',
      icon: Icons.currency_exchange_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Fee account ID',
            controller: feeAccountController,
            required: true,
          ),
          AksharaFormField(
            label: 'Student name',
            controller: studentNameController,
          ),
          AksharaFormField(
            label: 'Admission number',
            controller: admissionController,
          ),
          AksharaFormField(
            label: 'Class',
            controller: classController,
          ),
          AksharaFormField(
            label: 'Refund amount',
            controller: amountController,
            required: true,
          ),
          AksharaFormField(
            label: 'Reason',
            controller: reasonController,
            required: true,
          ),
          AksharaFormField(
            label: 'Original receipt',
            controller: receiptController,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Submit',
        confirmKey: QaTestKeys.financeCreateRefundSubmitButton,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final created = await ref.read(createRefundProvider.notifier).execute(
          CreateRefundRequest(
            feeAccountId: feeAccountController.text.trim(),
            amount: amountController.text.trim(),
            reason: reasonController.text.trim(),
            studentName: studentNameController.text.trim(),
            admissionNumber: admissionController.text.trim(),
            classLabel: classController.text.trim(),
            originalReceipt: receiptController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeRefundCreatedSnackbar,
        content: Text(
          created == null
              ? 'Refund request could not be created'
              : 'Refund request created for ${created.studentName}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> showAssignFeeConcessionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final studentNameController = TextEditingController(text: 'Arjun Patel');
  final feeAccountController = TextEditingController(text: 'acct_1');
  final amountController = TextEditingController(text: '₹15,000');
  final reasonController =
      TextEditingController(text: 'Merit scholarship — Term 2');

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Assign fee concession',
      icon: Icons.school_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Student name',
            controller: studentNameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Fee account ID',
            controller: feeAccountController,
          ),
          AksharaFormField(
            label: 'Concession amount',
            controller: amountController,
            required: true,
          ),
          AksharaFormField(
            label: 'Reason',
            controller: reasonController,
            required: true,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Submit for approval',
        confirmKey: QaTestKeys.financeAssignConcessionSubmitButton,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final concessionId =
        await ref.read(assignFeeConcessionProvider.notifier).execute(
              studentName: studentNameController.text.trim(),
              feeAccountId: feeAccountController.text.trim(),
              amount: amountController.text.trim(),
              reason: reasonController.text.trim(),
            );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeAssignConcessionSuccessSnackbar,
        content: Text(
          concessionId == null
              ? 'Concession could not be submitted'
              : 'Concession submitted for principal approval ($concessionId)',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
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

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Create scholarship',
      icon: Icons.school_outlined,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Scholarship name',
            controller: nameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Max discount',
            controller: discountController,
          ),
          AksharaFormField(
            label: 'Eligibility',
            controller: eligibilityController,
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Create',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
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

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Edit ${item.label}',
      icon: Icons.tune_rounded,
      content: AksharaFormField(
        label: item.label,
        controller: valueController,
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Save',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
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

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Record collection',
      icon: Icons.payments_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            key: QaTestKeys.financeCollectionInvoiceField,
            label: 'Invoice ID',
            controller: invoiceController,
          ),
          AksharaFormField(
            key: QaTestKeys.financeCollectionAmountField,
            label: 'Amount collected',
            controller: amountController,
            keyboardType: TextInputType.number,
          ),
          DropdownMenu<String>(
            initialSelection: paymentMethod,
            label: const Text('Payment method'),
            expandedInsets: EdgeInsets.zero,
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
      actions: _dialogActions(
        context,
        confirmLabel: 'Record payment',
        confirmKey: QaTestKeys.financeCollectionSubmitButton,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
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
  final confirmed = await showAksharaConfirmDialog(
    context,
    title: 'Cancel invoice',
    message: 'Cancel invoice $invoiceId? This cannot be undone.',
    confirmLabel: 'Cancel invoice',
    cancelLabel: 'Keep',
    destructive: true,
    confirmKey: QaTestKeys.financeCancelInvoiceConfirmButton,
  );
  if (!confirmed || !context.mounted) return;

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
  final confirmed = await showAksharaConfirmDialog(
    context,
    title: 'Cancel collection',
    message:
        'Cancel receipt $receiptNumber? The payment will be marked refunded.',
    confirmLabel: 'Cancel collection',
    cancelLabel: 'Keep',
    destructive: true,
    confirmKey: QaTestKeys.financeCancelCollectionConfirmButton,
  );
  if (!confirmed || !context.mounted) return;

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
