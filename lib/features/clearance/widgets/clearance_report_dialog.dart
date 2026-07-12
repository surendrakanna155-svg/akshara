import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../theme/theme_extensions.dart';
import '../clearance_datasource.dart';
import '../clearance_models.dart';
import '../clearance_providers.dart';

/// SCE-1 slice 4 — the Student Clearance / No-Dues report dialog. Shows each
/// module's clearance status (finance/inventory/library/hostel) honestly,
/// including `not_tracked` coverage caveats, and — when the student is BLOCKED
/// and the viewer can raise a waiver (manageSis) — offers the maker-checker
/// dues-waiver request. Read-first; the waiver is the sanctioned override.
class ClearanceReportDialog extends ConsumerWidget {
  const ClearanceReportDialog({super.key, required this.studentId, required this.studentName});

  final String studentId;
  final String studentName;

  static Future<void> show(
    BuildContext context, {
    required String studentId,
    required String studentName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ClearanceReportDialog(studentId: studentId, studentName: studentName),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentClearanceReportProvider(studentId));
    return AlertDialog(
      key: const Key('clearance-report-dialog'),
      title: Text('Clearance — $studentName'),
      content: SizedBox(
        width: 420,
        child: async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Text(
            'Could not load the clearance report. Try again.',
            style: context.aksharaText.bodyMedium,
          ),
          data: (report) => _ReportBody(report: report, studentId: studentId),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report, required this.studentId});

  final ClearanceReport report;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final scheme = Theme.of(context).colorScheme;
    final canWaive = ref.watch(rbacServiceProvider).hasPermission(Permission.manageSis);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline verdict.
        Container(
          key: const Key('clearance-verdict'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: report.blocked ? scheme.errorContainer : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(report.blocked ? Icons.block : Icons.verified_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.blocked
                      ? 'Blocked — ₹${report.blockingAmount.toStringAsFixed(0)} in dues must be cleared or waived'
                      : 'Cleared — no blocking dues',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final c in report.contributions) _ContributionRow(contribution: c),
        if (report.notTracked.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Not yet tracked: ${report.notTracked.join(', ')} '
            '(no per-student dues ledger — shown for transparency, never assumed clear).',
            key: const Key('clearance-not-tracked-note'),
            style: text.bodySmall,
          ),
        ],
        if (report.blocked && canWaive) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const Key('clearance-request-waiver-button'),
              onPressed: () => _openWaiverDialog(context, ref),
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('Request dues waiver'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openWaiverDialog(BuildContext context, WidgetRef ref) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _WaiverRequestDialog(studentId: studentId, amount: report.blockingAmount),
    );
    if (submitted == true) {
      // Refresh the report so the caveat/verdict reflect the new pending waiver.
      ref.invalidate(studentClearanceReportProvider(studentId));
    }
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.contribution});
  final ClearanceContribution contribution;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final (IconData icon, String label) = switch (contribution.status) {
      'pending' => (Icons.error_outline, 'Pending'),
      'cleared' => (Icons.check_circle_outline, 'Cleared'),
      _ => (Icons.help_outline, 'Not tracked'),
    };
    final title = contribution.module.isEmpty
        ? 'Module'
        : contribution.module[0].toUpperCase() + contribution.module.substring(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: text.bodyMedium)),
          Text(
            contribution.isPending && contribution.amount > 0
                ? '$label · ₹${contribution.amount.toStringAsFixed(0)}'
                : label,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WaiverRequestDialog extends ConsumerStatefulWidget {
  const _WaiverRequestDialog({required this.studentId, required this.amount});
  final String studentId;
  final double amount;

  @override
  ConsumerState<_WaiverRequestDialog> createState() => _WaiverRequestDialogState();
}

class _WaiverRequestDialogState extends ConsumerState<_WaiverRequestDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'Give a reason (at least 3 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(clearanceDataSourceProvider).raiseWaiver(
            studentId: widget.studentId,
            reason: reason,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ClearanceWaiverRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send the request. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return AlertDialog(
      key: const Key('clearance-waiver-request-dialog'),
      title: const Text('Request dues waiver'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A waiver of ₹${widget.amount.toStringAsFixed(0)} needs a second '
            'approver (maker-checker) before it can clear the exit.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('clearance-waiver-reason'),
            controller: _reason,
            enabled: !_busy,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Reason',
              hintText: 'e.g. small balance waived at management discretion',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('clearance-waiver-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send for approval'),
        ),
      ],
    );
  }
}
