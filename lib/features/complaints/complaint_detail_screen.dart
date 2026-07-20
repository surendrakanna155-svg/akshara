import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_manage_action.dart';
import '../../shared/widgets/akshara_section_header.dart';
import '../../shared/widgets/akshara_status_chip.dart';
import '../../shared/widgets/akshara_warning_banner.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'complaints_datasource.dart';
import 'complaints_models.dart';
import 'complaints_providers.dart';

/// PRC-A Batch 2 — a single complaint: detail + the full event timeline.
/// Assign / status-transition / vendor actions are gated on `manageComplaints`
/// (`AksharaManageAction`). The comment box is open to anyone who reached this
/// screen (the server's own gate — `requireAnyComplaintsAccess` — already
/// scoped who can see a given complaint before this screen renders).
class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = resolveErpAsync(
      ref.watch(complaintDetailProvider(complaintId)),
      errorMessage: 'Unable to load this complaint.',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint')),
      body: ErpAsyncBody<Complaint>(
        state: viewState,
        loadingLabel: 'Loading complaint',
        emptyMessage: 'This complaint could not be found.',
        onRetry: () => retryErpFuture(ref, complaintDetailProvider(complaintId)),
        builder: (complaint) => _ComplaintDetailBody(complaint: complaint),
      ),
    );
  }
}

class _ComplaintDetailBody extends ConsumerWidget {
  const _ComplaintDetailBody({required this.complaint});
  final Complaint complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (complaint.isBreached)
          Padding(
            padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
            child: AksharaWarningBanner(
              key: const Key('complaint-detail-sla-breach'),
              message: 'SLA breached — response was due ${complaint.slaDueAt}.',
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(complaint.title, style: text.titleLarge),
            ),
            _severityChip(complaint.severity),
            const SizedBox(width: AksharaSpacing.s2),
            _statusChip(complaint.status),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s2),
        Text(complaint.description, style: text.bodyMedium),
        const SizedBox(height: AksharaSpacing.s4),
        _FactRow(label: 'Category', value: complaint.category),
        _FactRow(label: 'Raised by role', value: complaint.raisedByRole),
        _FactRow(
          label: 'Assigned to',
          value: complaint.isAssigned ? complaint.assignedTo! : 'Unassigned',
        ),
        if (complaint.relatedStudentId != null)
          _FactRow(label: 'Related student', value: complaint.relatedStudentId!),
        if (complaint.resolutionNote != null)
          _FactRow(label: 'Resolution note', value: complaint.resolutionNote!),
        if (complaint.vendorId != null)
          _FactRow(
            label: 'Vendor',
            value: complaint.repairCost != null
                ? '${complaint.vendorId} (₹${complaint.repairCost!.toStringAsFixed(0)})'
                : complaint.vendorId!,
          ),
        const SizedBox(height: AksharaSpacing.s5),
        AksharaManageAction(
          permission: Permission.manageComplaints,
          // This screen is pushed from ComplaintsScreen rather than routed, so
          // there is no /complaints/detail route to name; a denied action is
          // audited against the route the user is actually on.
          auditRoute: RouteNames.complaints,
          child: _ManageActionsRow(complaint: complaint),
        ),
        const SizedBox(height: AksharaSpacing.s5),
        const AksharaSectionHeader(title: 'Timeline', fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s2),
        for (final event in complaint.events) _EventTile(event: event),
        const SizedBox(height: AksharaSpacing.s5),
        _CommentBox(complaintId: complaint.id),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: text.bodySmall.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _ManageActionsRow extends StatelessWidget {
  const _ManageActionsRow({required this.complaint});
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AksharaSpacing.s2,
      runSpacing: AksharaSpacing.s2,
      children: [
        OutlinedButton.icon(
          key: const Key('complaint-detail-assign-button'),
          onPressed: () => _openAssignDialog(context),
          icon: const Icon(Icons.person_add_alt_outlined, size: 18),
          label: const Text('Assign'),
        ),
        if (complaint.legalNextStatuses.isNotEmpty)
          OutlinedButton.icon(
            key: const Key('complaint-detail-status-button'),
            onPressed: () => _openStatusDialog(context),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Change status'),
          ),
        OutlinedButton.icon(
          key: const Key('complaint-detail-vendor-button'),
          onPressed: () => _openVendorDialog(context),
          icon: const Icon(Icons.build_outlined, size: 18),
          label: const Text('Attach vendor'),
        ),
      ],
    );
  }

  void _openAssignDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _AssignDialog(complaintId: complaint.id),
    );
  }

  void _openStatusDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _StatusTransitionDialog(complaint: complaint),
    );
  }

  void _openVendorDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _VendorDialog(complaintId: complaint.id),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final ComplaintEvent event;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final icon = switch (event.eventType) {
      'raised' => Icons.flag_outlined,
      'assigned' => Icons.person_add_alt_outlined,
      'status_changed' => Icons.swap_horiz,
      'resolved' => Icons.check_circle_outline,
      'closed' => Icons.lock_outline,
      'reopened' => Icons.refresh,
      'commented' => Icons.chat_bubble_outline,
      _ => Icons.circle_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.eventType} — ${event.actorName?.isNotEmpty == true ? event.actorName : event.actorId}',
                  style: text.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                if (event.note != null && event.note!.isNotEmpty)
                  Text(event.note!, style: text.bodySmall),
                Text(
                  event.occurredAt,
                  style: text.bodySmall.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBox extends ConsumerStatefulWidget {
  const _CommentBox({required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<_CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends ConsumerState<_CommentBox> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _note.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'Write a comment first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(complaintsDataSourceProvider).comment(id: widget.complaintId, note: note);
      if (!mounted) return;
      _note.clear();
      ref.invalidate(complaintDetailProvider(widget.complaintId));
      setState(() => _busy = false);
    } on ComplaintActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not post the comment. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('complaint-detail-comment-field'),
          controller: _note,
          enabled: !_busy,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Add a comment',
            errorText: _error,
          ),
        ),
        const SizedBox(height: AksharaSpacing.s2),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const Key('complaint-detail-comment-submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post comment'),
          ),
        ),
      ],
    );
  }
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  final _assignedTo = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _assignedTo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final assignedTo = _assignedTo.text.trim();
    if (assignedTo.isEmpty) {
      setState(() => _error = 'Enter a staff user ID to assign to.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(complaintsDataSourceProvider)
          .assign(id: widget.complaintId, assignedTo: assignedTo);
      if (!mounted) return;
      ref.invalidate(complaintDetailProvider(widget.complaintId));
      Navigator.of(context).pop();
    } on ComplaintActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not assign the complaint. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('complaint-assign-dialog'),
      title: const Text('Assign complaint'),
      content: TextField(
        key: const Key('complaint-assign-user-field'),
        controller: _assignedTo,
        enabled: !_busy,
        decoration: InputDecoration(labelText: 'Assignee user ID', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('complaint-assign-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _StatusTransitionDialog extends ConsumerStatefulWidget {
  const _StatusTransitionDialog({required this.complaint});
  final Complaint complaint;

  @override
  ConsumerState<_StatusTransitionDialog> createState() => _StatusTransitionDialogState();
}

class _StatusTransitionDialogState extends ConsumerState<_StatusTransitionDialog> {
  late String _target = widget.complaint.legalNextStatuses.first;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _note.text.trim();
    if (_target == 'resolved' && note.isEmpty) {
      setState(() => _error = 'A resolution note is required to resolve a complaint.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(complaintsDataSourceProvider).updateStatus(
            id: widget.complaint.id,
            status: _target,
            resolutionNote: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      ref.invalidate(complaintDetailProvider(widget.complaint.id));
      Navigator.of(context).pop();
    } on ComplaintActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not change the status. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.complaint.legalNextStatuses;
    return AlertDialog(
      key: const Key('complaint-status-dialog'),
      title: const Text('Change status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('complaint-status-target'),
            initialValue: _target,
            decoration: const InputDecoration(labelText: 'New status'),
            items: [
              for (final s in options) DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _target = v ?? _target),
          ),
          const AksharaDialogFieldGap(),
          TextField(
            key: const Key('complaint-status-note'),
            controller: _note,
            enabled: !_busy,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _target == 'resolved' ? 'Resolution note (required)' : 'Note (optional)',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('complaint-status-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _VendorDialog extends ConsumerStatefulWidget {
  const _VendorDialog({required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends ConsumerState<_VendorDialog> {
  final _vendorId = TextEditingController();
  final _repairCost = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _vendorId.dispose();
    _repairCost.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vendorId = _vendorId.text.trim();
    if (vendorId.isEmpty) {
      setState(() => _error = 'Enter a vendor ID.');
      return;
    }
    final costText = _repairCost.text.trim();
    double? cost;
    if (costText.isNotEmpty) {
      cost = double.tryParse(costText);
      if (cost == null || cost < 0) {
        setState(() => _error = 'Repair cost must be a non-negative number.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(complaintsDataSourceProvider).attachVendor(
            id: widget.complaintId,
            vendorId: vendorId,
            repairCost: cost,
          );
      if (!mounted) return;
      ref.invalidate(complaintDetailProvider(widget.complaintId));
      Navigator.of(context).pop();
    } on ComplaintActionRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not attach the vendor. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('complaint-vendor-dialog'),
      title: const Text('Attach vendor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('complaint-vendor-id-field'),
            controller: _vendorId,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Vendor ID'),
          ),
          const AksharaDialogFieldGap(),
          TextField(
            key: const Key('complaint-vendor-cost-field'),
            controller: _repairCost,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Repair cost (optional)',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('complaint-vendor-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Attach'),
        ),
      ],
    );
  }
}

AksharaStatusChip _statusChip(String status) => AksharaStatusChip(
      label: status,
      tone: switch (status) {
        'open' => KpiAccent.warning,
        'assigned' || 'in_progress' => KpiAccent.primary,
        'resolved' || 'closed' => KpiAccent.success,
        'reopened' => KpiAccent.error,
        _ => KpiAccent.neutral,
      },
    );

AksharaStatusChip _severityChip(String severity) => AksharaStatusChip(
      label: severity,
      tone: switch (severity) {
        'critical' => KpiAccent.error,
        'high' => KpiAccent.warning,
        'medium' => KpiAccent.primary,
        _ => KpiAccent.neutral,
      },
    );
