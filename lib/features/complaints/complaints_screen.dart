import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/akshara_dialog.dart';
import '../../shared/widgets/akshara_key_value_card.dart';
import '../../shared/widgets/akshara_status_chip.dart';
import '../../shared/widgets/akshara_warning_banner.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'complaint_detail_screen.dart';
import 'complaints_datasource.dart';
import 'complaints_models.dart';
import 'complaints_providers.dart';

/// PRC-A Batch 2 — Complaints / Internal Issues queue.
///
/// Any of raiseComplaint / manageComplaints / viewComplaintsPrincipal reaches
/// this screen (route-level gating is the router's job); the raise action is
/// separately gated on `raiseComplaint` in-widget since a bare manager/
/// principal may not hold it.
class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  String? _status;
  String? _category;
  String? _severity;

  ComplaintsFilter get _filter =>
      (status: _status, category: _category, assignedTo: null, severity: _severity);

  @override
  Widget build(BuildContext context) {
    final canRaise = ref.watch(rbacServiceProvider).hasPermission(Permission.raiseComplaint);
    final viewState = resolveErpAsync(
      ref.watch(complaintsListProvider(_filter)),
      errorMessage: 'Unable to load the complaints queue.',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
      ),
      floatingActionButton: canRaise
          ? FloatingActionButton.extended(
              key: const Key('complaints-raise-fab'),
              onPressed: () => _openRaiseDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Raise complaint'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterBar(
              status: _status,
              category: _category,
              severity: _severity,
              onStatusChanged: (v) => setState(() => _status = v),
              onCategoryChanged: (v) => setState(() => _category = v),
              onSeverityChanged: (v) => setState(() => _severity = v),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Expanded(
              child: ErpAsyncBody<List<Complaint>>(
                state: viewState,
                loadingLabel: 'Loading complaints',
                emptyMessage: 'No complaints match these filters.',
                emptyIcon: Icons.forum_outlined,
                onRetry: () => retryErpFuture(ref, complaintsListProvider(_filter)),
                builder: (items) => _ComplaintsList(items: items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRaiseDialog(BuildContext context) async {
    final raised = await showDialog<bool>(
      context: context,
      builder: (_) => const _RaiseComplaintDialog(),
    );
    if (raised == true) {
      ref.invalidate(complaintsListProvider(_filter));
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.category,
    required this.severity,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onSeverityChanged,
  });

  final String? status;
  final String? category;
  final String? severity;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSeverityChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s2,
      children: [
        _FilterDropdown(
          key: const Key('complaints-filter-status'),
          label: 'Status',
          value: status,
          options: kComplaintStatuses,
          onChanged: onStatusChanged,
        ),
        _FilterDropdown(
          key: const Key('complaints-filter-category'),
          label: 'Category',
          value: category,
          options: kComplaintCategories,
          onChanged: onCategoryChanged,
        ),
        _FilterDropdown(
          key: const Key('complaints-filter-severity'),
          label: 'Severity',
          value: severity,
          options: kComplaintSeverities,
          onChanged: onSeverityChanged,
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: Text(label),
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('All $label')),
        for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}

class _ComplaintsList extends StatelessWidget {
  const _ComplaintsList({required this.items});
  final List<Complaint> items;

  @override
  Widget build(BuildContext context) {
    final breached = items.where((c) => c.isBreached).length;
    return ListView(
      children: [
        if (breached > 0) ...[
          AksharaWarningBanner(
            key: const Key('complaints-sla-breach-banner'),
            message: '$breached complaint${breached == 1 ? '' : 's'} breached SLA — needs attention.',
          ),
          const SizedBox(height: AksharaSpacing.s3),
        ],
        for (final c in items) ...[
          _ComplaintRow(complaint: c),
          const SizedBox(height: AksharaSpacing.s3),
        ],
      ],
    );
  }
}

class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.complaint});
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('complaint-row-${complaint.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(complaintId: complaint.id),
        ),
      ),
      child: AksharaKeyValueCard(
        titleWidget: Row(
          children: [
            Expanded(
              child: Text(
                complaint.title,
                style: context.aksharaText.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AksharaSpacing.s2),
            _severityChip(complaint.severity),
            const SizedBox(width: AksharaSpacing.s2),
            _statusChip(complaint.status),
          ],
        ),
        entries: [
          ('Category', complaint.category),
          ('Raised by', complaint.raisedByRole),
          if (complaint.isAssigned) ('Assigned to', complaint.assignedTo!),
          (
            'SLA',
            complaint.isBreached ? 'Breached — due ${complaint.slaDueAt}' : 'On track',
          ),
        ],
        trailing: complaint.isBreached
            ? Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20)
            : null,
      ),
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

class _RaiseComplaintDialog extends ConsumerStatefulWidget {
  const _RaiseComplaintDialog();

  @override
  ConsumerState<_RaiseComplaintDialog> createState() => _RaiseComplaintDialogState();
}

class _RaiseComplaintDialogState extends ConsumerState<_RaiseComplaintDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _relatedStudentId = TextEditingController();
  String _category = kComplaintCategories.first;
  String _severity = 'medium';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _relatedStudentId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Give a title (at least 3 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(complaintsDataSourceProvider).raise(
            category: _category,
            title: title,
            description: _description.text.trim(),
            severity: _severity,
            relatedStudentId: _relatedStudentId.text.trim().isEmpty
                ? null
                : _relatedStudentId.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        _error = 'Could not send the complaint. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('complaints-raise-dialog'),
      title: const Text('Raise a complaint'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('complaints-raise-category'),
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in kComplaintCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _category = v ?? _category),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('complaints-raise-title'),
                controller: _title,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('complaints-raise-description'),
                controller: _description,
                enabled: !_busy,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const AksharaDialogFieldGap(),
              DropdownButtonFormField<String>(
                key: const Key('complaints-raise-severity'),
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: [
                  for (final s in kComplaintSeverities)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _severity = v ?? _severity),
              ),
              const AksharaDialogFieldGap(),
              TextField(
                key: const Key('complaints-raise-related-student'),
                controller: _relatedStudentId,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Related student ID (optional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('complaints-raise-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
