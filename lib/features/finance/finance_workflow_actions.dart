import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/finance_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/reliability/drafts/draft_autosave.dart';
import '../../core/reliability/drafts/draft_model.dart';
import '../../core/reliability/drafts/draft_providers.dart';
import '../../core/reliability/model/draft_record.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/forms/akshara_form_field.dart';
import '../../shared/forms/akshara_searchable_dropdown.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_motion.dart';
import '../../shared/widgets/akshara_queued_view.dart';
import '../../shared/widgets/akshara_success_view.dart';
import 'finance_journey_context_provider.dart';
import 'fee_assignment/finance_fee_assignment_provider.dart';
import 'invoices/finance_invoices_provider.dart';
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
  final feeAccountController = TextEditingController();
  final studentNameController = TextEditingController();
  final admissionController = TextEditingController();
  final classController = TextEditingController();
  final amountController = TextEditingController();
  final reasonController = TextEditingController();
  final receiptController = TextEditingController();

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
            hint: 'e.g. acct_1024',
          ),
          AksharaFormField(
            label: 'Student name',
            controller: studentNameController,
            hint: 'Student this refund is for',
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
            hint: 'Amount to refund',
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
  final studentNameController = TextEditingController();
  final feeAccountController = TextEditingController();
  final amountController = TextEditingController();
  final reasonController = TextEditingController();

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
            hint: 'Student receiving the concession',
          ),
          AksharaFormField(
            label: 'Fee account ID',
            controller: feeAccountController,
            hint: 'e.g. acct_1024',
          ),
          AksharaFormField(
            label: 'Concession amount',
            controller: amountController,
            required: true,
            hint: 'Concession / scholarship amount',
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

Future<void> showCreateDiscountRuleDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final discountController = TextEditingController(text: '10%');
  final appliesToController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Add discount rule',
      icon: Icons.percent_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Rule name',
            controller: nameController,
            required: true,
            hint: 'e.g. Early bird payment',
          ),
          AksharaFormField(
            label: 'Discount',
            controller: discountController,
            hint: 'e.g. 5% or Up to 40%',
          ),
          AksharaFormField(
            label: 'Applies to',
            controller: appliesToController,
            hint: 'e.g. Annual fee — paid before 30 Apr',
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Create',
        confirmKey: QaTestKeys.financeDiscountRuleCreateSubmitButton,
        onConfirm: () {
          if (nameController.text.trim().isEmpty) return;
          Navigator.of(context).pop(true);
        },
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(createDiscountRuleProvider.notifier).execute(
          CreateDiscountRuleRequest(
            name: nameController.text.trim(),
            discountPercent: discountController.text.trim(),
            appliesTo: appliesToController.text.trim(),
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Discount rule created (pending approval)')),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

Future<void> showEditDiscountRuleDialog(
  BuildContext context,
  WidgetRef ref, {
  required DiscountRule rule,
}) async {
  final nameController = TextEditingController(text: rule.name);
  final discountController = TextEditingController(text: rule.discountPercent);
  final appliesToController = TextEditingController(text: rule.appliesTo);
  var status = rule.status;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Edit discount rule',
      icon: Icons.edit_outlined,
      scrollable: true,
      content: AksharaDialogFormBody(
        children: [
          AksharaFormField(
            label: 'Rule name',
            controller: nameController,
            required: true,
          ),
          AksharaFormField(
            label: 'Discount',
            controller: discountController,
          ),
          AksharaFormField(
            label: 'Applies to',
            controller: appliesToController,
          ),
          DropdownMenu<DiscountApprovalStatus>(
            initialSelection: status,
            label: const Text('Status'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: const [
              DropdownMenuEntry(
                value: DiscountApprovalStatus.pending,
                label: 'Pending',
              ),
              DropdownMenuEntry(
                value: DiscountApprovalStatus.approved,
                label: 'Approved',
              ),
              DropdownMenuEntry(
                value: DiscountApprovalStatus.active,
                label: 'Active',
              ),
              DropdownMenuEntry(
                value: DiscountApprovalStatus.rejected,
                label: 'Rejected',
              ),
            ],
            onSelected: (value) {
              if (value != null) status = value;
            },
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Save',
        confirmKey: QaTestKeys.financeDiscountRuleEditSubmitButton,
        onConfirm: () {
          if (nameController.text.trim().isEmpty) return;
          Navigator.of(context).pop(true);
        },
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(updateDiscountRuleProvider.notifier).execute(
          ruleId: rule.id,
          request: UpdateDiscountRuleRequest(
            name: nameController.text.trim(),
            discountPercent: discountController.text.trim(),
            appliesTo: appliesToController.text.trim(),
            status: status,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Discount rule updated')),
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

/// Strips currency symbols / grouping so a displayed dues figure (e.g. `₹5,000`)
/// becomes the plain number (`5000`) the collection request expects.
String _numericAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
  return cleaned;
}

Future<void> showRecordCollectionDialog(
  BuildContext context,
  WidgetRef ref, {
  String defaultInvoiceId = 'inv_1',
  String? defaultAmount,
  String? studentLabel,
  String? duesLabel,
}) async {
  final journeyInvoice = ref.read(financeLastInvoiceIdProvider);
  final invoices = ref.read(financeInvoicesProvider);

  // Build picker options (label <-> id) from the loaded invoices so the cashier
  // selects a real invoice instead of typing a raw ID. Falls back to a
  // free-text field if no invoices are loaded (e.g. empty/offline repo).
  final labelById = <String, String>{
    for (final inv in invoices)
      inv.id: '${inv.invoiceNumber} · ${inv.termLabel} · '
          '${inv.outstandingAmount} due',
  };
  final idByLabel = {for (final e in labelById.entries) e.value: e.key};
  // P2-UX-2 §2.4 — real dues source: each invoice's outstanding (and any accrued
  // late fee) drives both the prefilled amount and the on-dialog breakdown line,
  // replacing the old hardcoded '5000'.
  final outstandingById = <String, String>{
    for (final inv in invoices) inv.id: _numericAmount(inv.outstandingAmount),
  };
  final outstandingDisplayById = <String, String>{
    for (final inv in invoices) inv.id: inv.outstandingAmount,
  };
  final lateFeeById = <String, String>{
    for (final inv in invoices)
      if (inv.hasLateFee) inv.id: inv.lateFeeAmount,
  };
  final usePicker = invoices.isNotEmpty;

  final preferredId =
      (journeyInvoice != null && labelById.containsKey(journeyInvoice))
          ? journeyInvoice
          : (labelById.containsKey(defaultInvoiceId)
              ? defaultInvoiceId
              : (invoices.isNotEmpty
                  ? invoices.first.id
                  : (journeyInvoice ?? defaultInvoiceId)));

  // P2-UX-2 §2.4 — the initial amount is the REAL dues, not a magic number: an
  // explicit caller-supplied figure (e.g. a student's balance from the accounts
  // search) wins; otherwise the preferred invoice's outstanding; otherwise blank
  // (a free-text repo with no invoices — never fabricate an amount).
  final initialAmount = (defaultAmount != null && defaultAmount.trim().isNotEmpty)
      ? _numericAmount(defaultAmount)
      : (usePicker ? (outstandingById[preferredId] ?? '') : '');

  // REL-3 — field state + draft autosave/recovery live in a ConsumerStatefulWidget
  // so an interrupted collection (phone-lock / app-switch / kill) is never lost.
  // The form reports the live values back through [onChanged]; the outer flow
  // keeps ownership of the actual money mutation + success/error handling.
  var invoiceId = preferredId;
  var amount = initialAmount;
  var paymentMethod = 'UPI';

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Record collection',
      icon: Icons.payments_outlined,
      scrollable: true,
      content: _RecordCollectionForm(
        usePicker: usePicker,
        labelById: labelById,
        idByLabel: idByLabel,
        outstandingById: outstandingById,
        outstandingDisplayById: outstandingDisplayById,
        lateFeeById: lateFeeById,
        studentLabel: studentLabel,
        duesLabel: duesLabel,
        initialInvoiceId: preferredId,
        initialAmount: initialAmount,
        initialMethod: paymentMethod,
        onChanged: (i, a, m) {
          invoiceId = i;
          amount = a;
          paymentMethod = m;
        },
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
            invoiceId: invoiceId.trim(),
            amountCollected: amount.trim(),
            paymentMethod: paymentMethod,
            collectionDate: 'Today',
          ),
        );
    // REL-3 — a recorded (or safely queued) collection is done: drop the draft
    // so it is never re-offered. Fees are INSERT + idempotency-key (REL-1), so
    // there is no base row_version to overwrite (REL-5 documents this: the
    // idempotency key — not optimistic concurrency — dedupes a retried collect).
    unawaited(
      ref.read(draftControllerProvider).discard(_kFeeCollectionDraftKey),
    );
    if (!context.mounted || result == null) return;
    if (result.pendingSync) {
      // Refinement R1: an offline-recorded collection is NOT server-confirmed.
      // P2-UX-2 §2.4 — close with the honest amber "queued receipt" ceremony
      // (AksharaQueuedView, which fires the WARNING haptic) instead of a green
      // success beat: the money is safely captured but the receipt is issued
      // only after the Sync Center confirms the transaction.
      await showAksharaDialog<void>(
        context: context,
        builder: (queuedContext) => Dialog(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AksharaQueuedView(
              key: QaTestKeys.financeCollectionQueuedCard,
              title: 'Payment queued',
              highlight: '₹${amount.trim()}',
              subtitle: 'Saved offline — the receipt is issued once it syncs.',
              caption: '$paymentMethod · pending sync',
              primaryLabel: 'Done',
              onPrimary: () => Navigator.of(queuedContext).pop(),
            ),
          ),
        ),
      );
    } else {
      // P2-UX-2 §2.4 — the Stripe-grade counter closes with a success ceremony
      // (shared AksharaSuccessView, which fires the success haptic on show)
      // instead of a bare snackbar: amount + receipt + method, one "Done".
      ref.read(financeLastReceiptNumberProvider.notifier).state =
          result.receiptNumber;
      await showAksharaDialog<void>(
        context: context,
        builder: (ceremonyContext) => Dialog(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AksharaSuccessView(
              key: QaTestKeys.financeCollectionSuccessCeremony,
              title: 'Payment received',
              highlight: '₹${amount.trim()}',
              subtitle: 'Receipt ${result.receiptNumber}',
              caption: paymentMethod,
              primaryLabel: 'Done',
              onPrimary: () => Navigator.of(ceremonyContext).pop(),
            ),
          ),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// REL-3 — one draft per cashier for the in-progress fee collection; scoped to
/// the signed-in user by [DraftController].
const String _kFeeCollectionDraftKey = 'fee_collection';

/// REL-3 — the "Record collection" form body, extracted into a
/// [ConsumerStatefulWidget] so it can mix in [DraftAutosaveMixin]: every field
/// change autosaves a debounced draft (and the draft is flushed when the app is
/// backgrounded), so a half-entered payment survives a phone-lock / app-switch /
/// kill. Because it is a money form, a recovered draft is never silently
/// prefilled — the cashier is asked to Resume or Discard first. The parent
/// dialog keeps ownership of the actual mutation; this widget only reports the
/// live field values back via [onChanged].
class _RecordCollectionForm extends ConsumerStatefulWidget {
  const _RecordCollectionForm({
    required this.usePicker,
    required this.labelById,
    required this.idByLabel,
    required this.outstandingById,
    required this.outstandingDisplayById,
    required this.lateFeeById,
    required this.studentLabel,
    required this.duesLabel,
    required this.initialInvoiceId,
    required this.initialAmount,
    required this.initialMethod,
    required this.onChanged,
  });

  final bool usePicker;
  final Map<String, String> labelById;
  final Map<String, String> idByLabel;

  /// invoice id → numeric outstanding (drives the amount prefill + auto-follow).
  final Map<String, String> outstandingById;

  /// invoice id → display outstanding (e.g. `₹5,000`) for the breakdown line.
  final Map<String, String> outstandingDisplayById;

  /// invoice id → accrued late fee display (only ids that have one).
  final Map<String, String> lateFeeById;

  /// Optional student context header (name · admission) when the collection was
  /// originated from the student-accounts search.
  final String? studentLabel;

  /// Optional dues summary (e.g. `Balance ₹12,500`) for the context header.
  final String? duesLabel;

  final String initialInvoiceId;
  final String initialAmount;
  final String initialMethod;
  final void Function(String invoiceId, String amount, String method) onChanged;

  @override
  ConsumerState<_RecordCollectionForm> createState() =>
      _RecordCollectionFormState();
}

class _RecordCollectionFormState extends ConsumerState<_RecordCollectionForm>
    with DraftAutosaveMixin {
  late final TextEditingController _invoiceController;
  late final TextEditingController _amountController;
  late String _selectedInvoiceId;
  late String _paymentMethod;

  /// A recoverable draft awaiting the cashier's Resume / Discard choice. Held
  /// (not applied) so we never silently prefill a money amount.
  DraftRecord? _recoverable;

  @override
  void initState() {
    super.initState();
    _selectedInvoiceId = widget.initialInvoiceId;
    _paymentMethod = widget.initialMethod;
    _invoiceController = TextEditingController(text: widget.initialInvoiceId)
      ..addListener(_notify);
    _amountController = TextEditingController(text: widget.initialAmount)
      ..addListener(_notify);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForDraft());
  }

  Future<void> _checkForDraft() async {
    final record = await draftController.recover(_kFeeCollectionDraftKey);
    if (record == null || !mounted) return;
    setState(() => _recoverable = record);
  }

  String get _effectiveInvoiceId =>
      widget.usePicker ? _selectedInvoiceId : _invoiceController.text.trim();

  /// Report the live values to the parent + schedule a debounced autosave.
  void _notify() {
    widget.onChanged(
      _effectiveInvoiceId,
      _amountController.text,
      _paymentMethod,
    );
    scheduleDraftSave();
  }

  void _resumeDraft() {
    final record = _recoverable;
    if (record == null) return;
    final json = record.json;
    final amount = json['amount']?.toString() ?? '';
    final method = json['method']?.toString();
    final invoiceId = json['invoiceId']?.toString();
    setState(() {
      if (amount.isNotEmpty) _amountController.text = amount;
      if (method != null && method.isNotEmpty) _paymentMethod = method;
      if (invoiceId != null &&
          invoiceId.isNotEmpty &&
          (!widget.usePicker || widget.labelById.containsKey(invoiceId))) {
        _selectedInvoiceId = invoiceId;
        _invoiceController.text = invoiceId;
      }
      _recoverable = null;
    });
    _notify();
  }

  void _discardDraft() {
    unawaited(discardDraftOnSubmit(_kFeeCollectionDraftKey));
    setState(() => _recoverable = null);
  }

  @override
  DraftModel? buildDraftSnapshot() {
    final amount = _amountController.text.trim();
    // Nothing worth saving until an amount is entered — never leave a stray
    // draft for an untouched form.
    if (amount.isEmpty) return null;
    return MapDraft(
      _kFeeCollectionDraftKey,
      <String, dynamic>{
        'invoiceId': _effectiveInvoiceId,
        'amount': amount,
        'method': _paymentMethod,
      },
      draftLabel: 'Fee collection',
    );
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AksharaDialogFormBody(
      children: [
        if (_recoverable != null) _buildResumePrompt(context),
        if (widget.studentLabel != null) _buildStudentHeader(context),
        if (widget.usePicker)
          AksharaSearchableDropdown(
            key: QaTestKeys.financeCollectionInvoiceField,
            label: 'Invoice',
            value: widget.labelById[_selectedInvoiceId] ??
                widget.labelById.values.first,
            options: widget.labelById.values.toList(),
            onChanged: (label) {
              final id = widget.idByLabel[label];
              if (id != null) {
                setState(() {
                  _selectedInvoiceId = id;
                  // P2-UX-2 §2.4 — switching invoice re-seeds the amount with the
                  // newly-selected invoice's real outstanding (the cashier can
                  // still edit down for a partial payment).
                  final outstanding = widget.outstandingById[id];
                  if (outstanding != null && outstanding.isNotEmpty) {
                    _amountController.text = outstanding;
                  }
                });
                _notify();
              }
            },
          )
        else
          AksharaFormField(
            key: QaTestKeys.financeCollectionInvoiceField,
            label: 'Invoice ID',
            controller: _invoiceController,
          ),
        if (widget.usePicker) _buildDuesLine(context),
        AksharaFormField(
          key: QaTestKeys.financeCollectionAmountField,
          label: 'Amount collected',
          controller: _amountController,
          keyboardType: TextInputType.number,
        ),
        DropdownMenu<String>(
          initialSelection: _paymentMethod,
          label: const Text('Payment method'),
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'Cash', label: 'Cash'),
            DropdownMenuEntry(value: 'UPI', label: 'UPI'),
            DropdownMenuEntry(value: 'Card', label: 'Card'),
          ],
          onSelected: (value) {
            if (value != null) {
              setState(() => _paymentMethod = value);
              _notify();
            }
          },
        ),
      ],
    );
  }

  Widget _buildResumePrompt(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You have an unsaved collection. Resume where you left off?',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: QaTestKeys.financeCollectionDraftDiscardButton,
                onPressed: _discardDraft,
                child: const Text('Discard'),
              ),
              TextButton(
                key: QaTestKeys.financeCollectionDraftResumeButton,
                onPressed: _resumeDraft,
                child: const Text('Resume'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// P2-UX-2 §2.4 — student context header when the collection was originated
  /// from the PSID/name/class accounts search: who is paying, and their dues.
  Widget _buildStudentHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.person_outline,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentLabel!,
                  style: theme.textTheme.titleSmall,
                ),
                if (widget.duesLabel != null)
                  Text(
                    widget.duesLabel!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// P2-UX-2 §2.4 — the live dues breakdown for the selected invoice: its real
  /// outstanding (and any accrued late fee), so the cashier sees exactly what is
  /// owed before confirming — no more guessing behind a hardcoded amount.
  Widget _buildDuesLine(BuildContext context) {
    final theme = Theme.of(context);
    final outstanding = widget.outstandingDisplayById[_selectedInvoiceId];
    if (outstanding == null || outstanding.isEmpty) {
      return const SizedBox.shrink();
    }
    final lateFee = widget.lateFeeById[_selectedInvoiceId];
    final duesText = (lateFee != null && lateFee.isNotEmpty)
        ? 'Outstanding $outstanding · incl. late fee $lateFee'
        : 'Outstanding $outstanding';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        key: QaTestKeys.financeCollectionDuesLine,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              duesText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
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
  // FIN-D3: a cancellation now requires a mandatory reason (captured + audited +
  // shown in the cancelled register).
  final reason = await _promptForReason(
    context,
    title: 'Cancel collection',
    message:
        'Cancel receipt $receiptNumber? The payment will be reversed. A reason is required.',
    confirmLabel: 'Cancel collection',
    confirmKey: QaTestKeys.financeCancelCollectionConfirmButton,
  );
  if (reason == null || !context.mounted) return;

  try {
    final result = await ref.read(cancelCollectionProvider.notifier).execute(
          collectionId: collectionId,
          reason: reason,
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

/// Confirmation dialog that captures a MANDATORY free-text reason (FIN-D3). The
/// confirm button stays disabled until a non-blank reason is entered; returns
/// the trimmed reason, or null if the user dismisses.
Future<String?> _promptForReason(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Key? confirmKey,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final reason = controller.text.trim();
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    hintText: 'e.g. duplicate entry, wrong amount',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Keep'),
              ),
              FilledButton(
                key: confirmKey,
                onPressed: reason.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(reason),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}
