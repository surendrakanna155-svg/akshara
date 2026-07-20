import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/finance_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
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
import 'discounts/finance_discounts_provider.dart';
import 'fee_assignment/finance_fee_assignment_provider.dart';
import 'invoices/finance_invoices_provider.dart';
import 'finance_models.dart';
import 'finance_mutations_provider.dart';
import 'finance_requests.dart';
import 'integration/finance_admissions_handoff_provider.dart';
import 'student_accounts/finance_student_accounts_provider.dart';

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

/// Cap 67 — "Unbound" sentinel for the class/section picker below (never a
/// real class/section name, since [classOptionsProvider]/[sectionOptionsProvider]
/// never return an empty string).
const _unboundOption = 'Unbound';

List<String> _sortedUniqueLabels(Iterable<String> values) {
  final unique = values.where((v) => v.isNotEmpty).toSet().toList();
  unique.sort();
  return unique;
}

typedef _ClassSectionChanged = void Function({
  String? className,
  String? sectionName,
});

/// Cap 67 — OPTIONAL class/section binding picker shared by the create/edit
/// fee-structure dialogs. Reuses the same academic catalog providers as the
/// bulk-assign dialog's class filter; the section list is scoped to whichever
/// class is currently selected (a section belongs to exactly one class).
class _ClassSectionBindingFields extends ConsumerStatefulWidget {
  const _ClassSectionBindingFields({
    required this.onChanged,
    this.initialClassName,
    this.initialSectionName,
  });

  final _ClassSectionChanged onChanged;
  final String? initialClassName;
  final String? initialSectionName;

  @override
  ConsumerState<_ClassSectionBindingFields> createState() =>
      _ClassSectionBindingFieldsState();
}

class _ClassSectionBindingFieldsState
    extends ConsumerState<_ClassSectionBindingFields> {
  late String _className;
  late String _sectionName;

  @override
  void initState() {
    super.initState();
    _className = (widget.initialClassName?.isNotEmpty ?? false)
        ? widget.initialClassName!
        : _unboundOption;
    _sectionName = (widget.initialSectionName?.isNotEmpty ?? false)
        ? widget.initialSectionName!
        : _unboundOption;
  }

  void _notify() {
    widget.onChanged(
      className: _className == _unboundOption ? null : _className,
      sectionName: _sectionName == _unboundOption ? null : _sectionName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classOptionsProvider);
    final catalog = ref.watch(academicCatalogProvider);
    final sectionsForClass = (catalog == null || _className == _unboundOption)
        ? const <String>[]
        : _sortedUniqueLabels(
            catalog.sections
                .where((s) => s.className == _className)
                .map((s) => s.sectionName),
          );
    if (_sectionName != _unboundOption &&
        !sectionsForClass.contains(_sectionName)) {
      // The class changed (or its sections loaded) since _sectionName was
      // picked — it no longer belongs to the selected class.
      _sectionName = _unboundOption;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          child: DropdownMenu<String>(
            key: QaTestKeys.financeFeeStructureClassField,
            initialSelection: _className,
            label: const Text('Bind to class (optional)'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: _unboundOption, label: _unboundOption),
              for (final c in classes)
                DropdownMenuEntry(value: c, label: 'Class $c'),
            ],
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                _className = value;
                _sectionName = _unboundOption;
              });
              _notify();
            },
          ),
        ),
        const SizedBox(height: 8),
        Material(
          child: DropdownMenu<String>(
            key: ValueKey('section-for-$_className'),
            initialSelection: _sectionName,
            label: const Text('Section (optional)'),
            expandedInsets: EdgeInsets.zero,
            enabled: _className != _unboundOption,
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: _unboundOption, label: _unboundOption),
              for (final s in sectionsForClass)
                DropdownMenuEntry(value: s, label: 'Section $s'),
            ],
            onSelected: _className == _unboundOption
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _sectionName = value);
                    _notify();
                  },
          ),
        ),
      ],
    );
  }
}

Future<void> showCreateFeeStructureDialog(
  BuildContext context,
  WidgetRef ref, {
  String academicYear = '2026-27',
}) async {
  final nameController = TextEditingController(text: 'New fee structure');
  final totalController = TextEditingController(text: '₹1,85,000');
  final classRangeController = TextEditingController(text: 'Nursery – 12');
  String? selectedClassName;
  String? selectedSectionName;

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
          const SizedBox(height: 8),
          _ClassSectionBindingFields(
            onChanged: ({className, sectionName}) {
              selectedClassName = className;
              selectedSectionName = sectionName;
            },
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
            // Cap 67 — real class/section binding (label-based; resolved
            // server-side against `academicYear`). Both null = unbound.
            className: selectedClassName,
            sectionName: selectedSectionName,
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
  final wasClassBound = structure.isClassBound;
  String? selectedClassName = structure.className;
  String? selectedSectionName = structure.sectionName;

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Edit fee structure',
      icon: Icons.edit_outlined,
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
          const SizedBox(height: 8),
          _ClassSectionBindingFields(
            initialClassName: structure.className,
            initialSectionName: structure.sectionName,
            onChanged: ({className, sectionName}) {
              selectedClassName = className;
              selectedSectionName = sectionName;
            },
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
    // Cap 67 — the picker went back to "Unbound" for a structure that WAS
    // bound: that's an explicit unbind, not "leave unchanged" (which is what
    // both fields being null would otherwise mean to the request contract).
    final unbindClass = wasClassBound && selectedClassName == null;
    await ref.read(updateFeeStructureProvider.notifier).execute(
          feeStructureId: structure.id,
          request: UpdateFeeStructureRequest(
            name: nameController.text.trim(),
            totalAnnual: totalController.text.trim(),
            unbindClass: unbindClass,
            className: unbindClass ? null : selectedClassName,
            sectionName: unbindClass ? null : selectedSectionName,
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

  final account = await ref.read(assignFeePlanProvider.notifier).execute(
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

  // #6 — carry the real fee-assignment id through so the "Generated fee
  // account" panel can offer a genuine Cancel action against it.
  final preview = buildFeeAccountPreview(
    handoffId: handoff.id,
    studentName: handoff.studentName,
    admissionNumber: handoff.admissionNumber,
    structure: structure,
    plan: plan,
    includeTransport: includeTransport,
    includeHostel: includeHostel,
    feeAssignmentId: account?.feeAssignmentId,
  );

  completeFinanceHandoffAssignment(
    ref,
    handoffId: handoff.id,
    preview: preview,
  );

  // #6 — pin the selection to the handoff just assigned. Without this, the
  // screen's fallback selection (`handoffQueue.first` over the PENDING-only
  // list) jumps to the next pending handoff the instant this one completes,
  // silently hiding the generated-account panel — and with it, the new
  // Cancel action — from the person who just created it.
  ref.read(financeSelectedHandoffIdProvider.notifier).state = handoff.id;
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

/// STEP-5 — P0 money-honesty fix (PRC-A cap 71). This used to fabricate a
/// `concession_<timestamp>` id and either submit a `feeConcession` approval
/// (the backend hardcodes `payableApplied: false` for that type — a row is
/// recorded but NO money ever moves) or apply an in-memory
/// `FinanceApprovalGovernanceStore` concession — neither ever reached the
/// student's real payable. It now performs the real MAKER step of the
/// certified, invoice-scoped fee-reduction maker-checker
/// (finance_fee_reductions_{repository,handlers}.ts): propose a scholarship
/// award or discount application against one of a specific student's OPEN
/// invoices. This moves NO money — a second, different, authorised person
/// (`Permission.approveFeeConcession`) must approve it from the "Pending
/// awards" section on the discounts screen before the payable actually drops.
Future<void> showAssignFeeConcessionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final discounts = ref.read(financeDiscountsProvider);
  final scholarships =
      discounts?.scholarships ?? const <ScholarshipCatalogItem>[];
  final rules = discounts?.rules ?? const <DiscountRule>[];

  // The discounts screen doesn't otherwise fetch student accounts / invoices
  // — await them here so the student → open-invoice pickers below always see
  // real data (never a transient empty list from an unloaded FutureProvider).
  await ref.read(financeStudentAccountsFutureProvider.future);
  await ref.read(financeInvoicesFutureProvider.future);
  if (!context.mounted) return;
  final studentAccounts = ref.read(financeStudentAccountsProvider);
  final invoices = ref.read(financeInvoicesProvider);

  if (scholarships.isEmpty && rules.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add a scholarship or discount rule before awarding one.',
        ),
      ),
    );
    return;
  }

  var selectedSourceKind = FeeReductionSourceKind.scholarship;
  var selectedSourceId = '';
  var selectedInvoiceId = '';
  var selectedReductionKind = FeeReductionKind.percent;
  var enteredValueText = '';
  var enteredReason = '';

  final reasonController = TextEditingController();

  final confirmed = await showAksharaDialog<bool>(
    context: context,
    builder: (context) => AksharaAlertDialog(
      title: 'Award a scholarship or discount',
      icon: Icons.school_outlined,
      scrollable: true,
      content: _AwardFeeReductionForm(
        scholarships: scholarships,
        rules: rules,
        studentAccounts: studentAccounts,
        invoices: invoices,
        reasonController: reasonController,
        onChanged: ({
          required FeeReductionSourceKind sourceKind,
          required String sourceId,
          required String invoiceId,
          required FeeReductionKind reductionKind,
          required String valueText,
        }) {
          selectedSourceKind = sourceKind;
          selectedSourceId = sourceId;
          selectedInvoiceId = invoiceId;
          selectedReductionKind = reductionKind;
          enteredValueText = valueText;
        },
      ),
      actions: _dialogActions(
        context,
        confirmLabel: 'Propose award',
        confirmKey: QaTestKeys.financeAssignConcessionSubmitButton,
        onConfirm: () {
          enteredReason = reasonController.text.trim();
          if (selectedInvoiceId.isEmpty) return;
          if (enteredReason.isEmpty) return;
          final value = double.tryParse(enteredValueText.trim());
          if (value == null || value <= 0) return;
          if (selectedReductionKind == FeeReductionKind.percent &&
              value > 100) {
            return;
          }
          Navigator.of(context).pop(true);
        },
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final value = double.tryParse(enteredValueText.trim()) ?? 0;
  final percent =
      selectedReductionKind == FeeReductionKind.percent ? value : null;
  final amount =
      selectedReductionKind == FeeReductionKind.fixed ? value : null;

  try {
    final FeeReduction? created;
    if (selectedSourceKind == FeeReductionSourceKind.scholarship) {
      created = await ref.read(proposeScholarshipAwardProvider.notifier).execute(
            scholarshipId: selectedSourceId,
            invoiceId: selectedInvoiceId,
            reason: enteredReason,
            percent: percent,
            amount: amount,
          );
    } else {
      created =
          await ref.read(proposeDiscountApplicationProvider.notifier).execute(
                discountRuleId: selectedSourceId,
                invoiceId: selectedInvoiceId,
                reason: enteredReason,
                percent: percent,
                amount: amount,
              );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeAssignConcessionSuccessSnackbar,
        content: Text(
          created == null
              ? 'Award could not be proposed'
              : 'Award proposed — the fee drops only after a second, '
                  'different person approves it.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// Reports the maker dialog's current picker/value selections back to the
/// enclosing [showAssignFeeConcessionDialog] on every change (mirrors the
/// `onChanged`-reporting pattern [_RecordCollectionForm] uses below). The
/// reason field is owned by the caller's [TextEditingController] directly
/// (read at confirm time) since it needs no dependent-picker reactions.
typedef _AwardFormChanged = void Function({
  required FeeReductionSourceKind sourceKind,
  required String sourceId,
  required String invoiceId,
  required FeeReductionKind reductionKind,
  required String valueText,
});

/// True for an invoice a fee reduction can actually target — mirrors the
/// backend's "not cancelled" gate plus "there is something to reduce" (an
/// issued or partially-paid invoice actually has an outstanding balance).
bool _isOpenInvoice(FinanceInvoice invoice) =>
    invoice.invoiceStatus == InvoiceStatus.issued ||
    invoice.invoiceStatus == InvoiceStatus.partiallyPaid;

/// Best-effort prefill: parses a scholarship/discount-rule display value like
/// `"25%"`, `"Up to 40%"`, or `"₹5,000"` into a reduction kind + plain number.
/// Returns null when the string doesn't cleanly parse (the maker types the
/// value manually instead — never a fabricated guess).
({FeeReductionKind kind, String value})? _parseSourceValueHint(String raw) {
  final trimmed = raw.trim();
  final percentMatch =
      RegExp(r'^(?:up to\s*)?(\d+(?:\.\d+)?)\s*%$', caseSensitive: false)
          .firstMatch(trimmed);
  if (percentMatch != null) {
    return (kind: FeeReductionKind.percent, value: percentMatch.group(1)!);
  }
  final fixedMatch =
      RegExp(r'^[₹Rr][Ss]?\.?\s*([\d,]+(?:\.\d+)?)$').firstMatch(trimmed);
  if (fixedMatch != null) {
    return (
      kind: FeeReductionKind.fixed,
      value: fixedMatch.group(1)!.replaceAll(',', ''),
    );
  }
  return null;
}

class _AwardFeeReductionForm extends StatefulWidget {
  const _AwardFeeReductionForm({
    required this.scholarships,
    required this.rules,
    required this.studentAccounts,
    required this.invoices,
    required this.reasonController,
    required this.onChanged,
  });

  final List<ScholarshipCatalogItem> scholarships;
  final List<DiscountRule> rules;
  final List<StudentFeeAccount> studentAccounts;
  final List<FinanceInvoice> invoices;
  final TextEditingController reasonController;
  final _AwardFormChanged onChanged;

  @override
  State<_AwardFeeReductionForm> createState() =>
      _AwardFeeReductionFormState();
}

class _AwardFeeReductionFormState extends State<_AwardFeeReductionForm> {
  late FeeReductionSourceKind _sourceKind;
  late String _sourceId;
  String? _studentAccountId;
  String? _invoiceId;
  FeeReductionKind _reductionKind = FeeReductionKind.percent;
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sourceKind = widget.scholarships.isNotEmpty
        ? FeeReductionSourceKind.scholarship
        : FeeReductionSourceKind.discount;
    _sourceId = _firstSourceId(_sourceKind);
    _studentAccountId = widget.studentAccounts.isNotEmpty
        ? widget.studentAccounts.first.id
        : null;
    _applySourcePrefill();
    _invoiceId = _openInvoicesForStudent.isNotEmpty
        ? _openInvoicesForStudent.first.id
        : null;
    // Report the initial selection so a confirm-without-touching-anything
    // still carries the defaulted values.
    _notify();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  String _firstSourceId(FeeReductionSourceKind kind) {
    if (kind == FeeReductionSourceKind.scholarship) {
      return widget.scholarships.isNotEmpty ? widget.scholarships.first.id : '';
    }
    return widget.rules.isNotEmpty ? widget.rules.first.id : '';
  }

  List<FinanceInvoice> get _openInvoicesForStudent {
    final account = widget.studentAccounts.cast<StudentFeeAccount?>().firstWhere(
          (a) => a?.id == _studentAccountId,
          orElse: () => null,
        );
    final feeAssignmentId = account?.feeAssignmentId;
    if (feeAssignmentId == null || feeAssignmentId.isEmpty) return const [];
    return widget.invoices
        .where(
          (inv) => inv.feeAssignmentId == feeAssignmentId && _isOpenInvoice(inv),
        )
        .toList(growable: false);
  }

  void _applySourcePrefill() {
    final rawValue = _sourceKind == FeeReductionSourceKind.scholarship
        ? widget.scholarships.cast<ScholarshipCatalogItem?>().firstWhere(
              (s) => s?.id == _sourceId,
              orElse: () => null,
            )?.maxDiscount
        : widget.rules.cast<DiscountRule?>().firstWhere(
              (r) => r?.id == _sourceId,
              orElse: () => null,
            )?.discountPercent;
    if (rawValue == null) return;
    final hint = _parseSourceValueHint(rawValue);
    if (hint == null) return;
    _reductionKind = hint.kind;
    _valueController.text = hint.value;
  }

  void _notify() {
    widget.onChanged(
      sourceKind: _sourceKind,
      sourceId: _sourceId,
      invoiceId: _invoiceId ?? '',
      reductionKind: _reductionKind,
      valueText: _valueController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceOptions = _sourceKind == FeeReductionSourceKind.scholarship
        ? <String, String>{
            for (final s in widget.scholarships)
              s.id: '${s.name} (up to ${s.maxDiscount})',
          }
        : <String, String>{
            for (final r in widget.rules) r.id: '${r.name} (${r.discountPercent})',
          };
    final sourceIdByLabel = {
      for (final e in sourceOptions.entries) e.value: e.key,
    };

    final studentOptions = <String, String>{
      for (final a in widget.studentAccounts)
        a.id: '${a.studentName} (${a.admissionNumber})',
    };
    final studentIdByLabel = {
      for (final e in studentOptions.entries) e.value: e.key,
    };

    final openInvoices = _openInvoicesForStudent;
    final invoiceOptions = <String, String>{
      for (final inv in openInvoices)
        inv.id: '${inv.invoiceNumber} · ${inv.termLabel} · '
            '${inv.outstandingAmount} due',
    };
    final invoiceIdByLabel = {
      for (final e in invoiceOptions.entries) e.value: e.key,
    };

    return AksharaDialogFormBody(
      children: [
        DropdownMenu<FeeReductionSourceKind>(
          key: QaTestKeys.financeAwardSourceKindField,
          initialSelection: _sourceKind,
          label: const Text('Award type'),
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: const [
            DropdownMenuEntry(
              value: FeeReductionSourceKind.scholarship,
              label: 'Scholarship',
            ),
            DropdownMenuEntry(
              value: FeeReductionSourceKind.discount,
              label: 'Discount rule',
            ),
          ],
          onSelected: (kind) {
            if (kind == null) return;
            setState(() {
              _sourceKind = kind;
              _sourceId = _firstSourceId(kind);
              _applySourcePrefill();
            });
            _notify();
          },
        ),
        if (sourceOptions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _sourceKind == FeeReductionSourceKind.scholarship
                  ? 'No scholarships in the catalog yet.'
                  : 'No discount rules yet.',
            ),
          )
        else
          AksharaSearchableDropdown(
            key: QaTestKeys.financeAwardSourceField,
            label: _sourceKind == FeeReductionSourceKind.scholarship
                ? 'Scholarship'
                : 'Discount rule',
            value: sourceOptions[_sourceId] ?? sourceOptions.values.first,
            options: sourceOptions.values.toList(),
            onChanged: (label) {
              final id = sourceIdByLabel[label];
              if (id == null) return;
              setState(() {
                _sourceId = id;
                _applySourcePrefill();
              });
              _notify();
            },
          ),
        if (studentOptions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No student fee accounts loaded yet.'),
          )
        else
          AksharaSearchableDropdown(
            key: QaTestKeys.financeAwardStudentField,
            label: 'Student',
            value:
                studentOptions[_studentAccountId] ?? studentOptions.values.first,
            options: studentOptions.values.toList(),
            onChanged: (label) {
              final id = studentIdByLabel[label];
              if (id == null) return;
              setState(() {
                _studentAccountId = id;
                _invoiceId = _openInvoicesForStudent.isNotEmpty
                    ? _openInvoicesForStudent.first.id
                    : null;
              });
              _notify();
            },
          ),
        if (invoiceOptions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'This student has no open invoices — an award needs one to '
              'target.',
            ),
          )
        else
          AksharaSearchableDropdown(
            key: QaTestKeys.financeAwardInvoiceField,
            label: 'Invoice',
            required: true,
            value: invoiceOptions[_invoiceId] ?? invoiceOptions.values.first,
            options: invoiceOptions.values.toList(),
            onChanged: (label) {
              final id = invoiceIdByLabel[label];
              if (id == null) return;
              setState(() => _invoiceId = id);
              _notify();
            },
          ),
        DropdownMenu<FeeReductionKind>(
          key: QaTestKeys.financeAwardReductionKindField,
          initialSelection: _reductionKind,
          label: const Text('Reduction type'),
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: const [
            DropdownMenuEntry(
              value: FeeReductionKind.percent,
              label: 'Percent of fee',
            ),
            DropdownMenuEntry(
              value: FeeReductionKind.fixed,
              label: 'Fixed amount',
            ),
          ],
          onSelected: (kind) {
            if (kind == null) return;
            setState(() => _reductionKind = kind);
            _notify();
          },
        ),
        AksharaFormField(
          key: QaTestKeys.financeAwardValueField,
          label: _reductionKind == FeeReductionKind.percent
              ? 'Percent off (%)'
              : 'Fixed amount (₹)',
          controller: _valueController,
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _notify(),
        ),
        AksharaFormField(
          key: QaTestKeys.financeAwardReasonField,
          label: 'Reason',
          controller: widget.reasonController,
          required: true,
        ),
      ],
    );
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

/// #6 — client wiring for the already-built `PATCH .../fee-structures/:id/
/// archive` endpoint (soft-retire; status → inactive). Mirrors
/// [executeCancelInvoice]'s confirm-then-mutate-then-snackbar shape.
Future<void> executeArchiveFeeStructure(
  BuildContext context,
  WidgetRef ref, {
  required String feeStructureId,
  required String feeStructureName,
}) async {
  final confirmed = await showAksharaConfirmDialog(
    context,
    title: 'Archive fee structure',
    message:
        'Archive "$feeStructureName"? It will no longer be offered for new '
        'fee assignments; existing student accounts are unaffected.',
    confirmLabel: 'Archive',
    cancelLabel: 'Keep',
    destructive: true,
    confirmKey: QaTestKeys.financeArchiveFeeStructureConfirmButton,
  );
  if (!confirmed || !context.mounted) return;

  try {
    final structure = await ref.read(archiveFeeStructureProvider.notifier).execute(
          feeStructureId: feeStructureId,
        );
    if (!context.mounted || structure == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeFeeStructureArchivedSnackbar,
        content: Text('${structure.name} archived'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showMutationError(context, error);
  }
}

/// #6 — client wiring for the already-built `PATCH .../fee-assignments/:id/
/// cancel` endpoint (assignment → cancelled, linked account → closed).
Future<void> executeCancelFeeAssignment(
  BuildContext context,
  WidgetRef ref, {
  required String feeAssignmentId,
  required String studentName,
}) async {
  final confirmed = await showAksharaConfirmDialog(
    context,
    title: 'Cancel fee assignment',
    message: 'Cancel the fee assignment for $studentName? The student fee '
        'account will be closed. This cannot be undone.',
    confirmLabel: 'Cancel assignment',
    cancelLabel: 'Keep',
    destructive: true,
    confirmKey: QaTestKeys.financeCancelFeeAssignmentConfirmButton,
  );
  if (!confirmed || !context.mounted) return;

  try {
    final account = await ref.read(cancelFeeAssignmentProvider.notifier).execute(
          feeAssignmentId: feeAssignmentId,
        );
    if (!context.mounted || account == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeFeeAssignmentCancelledSnackbar,
        content: Text('Fee assignment cancelled for ${account.studentName}'),
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
