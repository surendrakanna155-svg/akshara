import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../gate_pass_datasource.dart';
import '../gate_pass_models.dart';
import '../gate_pass_providers.dart';
import 'gate_pass_verify_dialog.dart';

/// Gate pass detail — display-only plus Cancel and (when verifiable) Verify.
/// Never shows an OTP/QR credential — the API never returns one.
class GatePassDetailDialog extends ConsumerStatefulWidget {
  const GatePassDetailDialog({super.key, required this.gatePass});

  final GatePass gatePass;

  @override
  ConsumerState<GatePassDetailDialog> createState() => _GatePassDetailDialogState();
}

class _GatePassDetailDialogState extends ConsumerState<GatePassDetailDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(gatePassDataSourceProvider).cancel(widget.gatePass.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on GatePassRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not cancel the pass. Try again.';
      });
    }
  }

  Future<void> _openVerify() async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (_) => GatePassVerifyDialog(gatePass: widget.gatePass),
    );
    if (verified == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = widget.gatePass;
    final text = context.aksharaText;
    final rbac = ref.watch(rbacServiceProvider);
    final canCancel = rbac.hasPermission(Permission.approveGatePass);
    final canVerify = rbac.hasPermission(Permission.verifyGatePass);

    return AlertDialog(
      key: const Key('gate-pass-detail-dialog'),
      title: Text(gatePassTypeLabel(pass.passType)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Status', style: text.bodyMedium),
                const SizedBox(width: AksharaSpacing.s2),
                AksharaStatusChip(
                  label: gatePassStatusLabel(pass.status),
                  tone: _toneFor(pass.status),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s3),
            _DetailRow(label: 'Student', value: pass.studentId),
            _DetailRow(label: 'Reason', value: pass.reason.isEmpty ? 'Not given' : pass.reason),
            _DetailRow(label: 'Scheduled', value: pass.scheduledAt),
            _DetailRow(label: 'Pickup person', value: pass.pickupPersonName),
            _DetailRow(
              label: 'Relation / phone',
              value: '${pass.pickupPersonRelation} · ${pass.pickupPersonPhone}',
            ),
            if (pass.isUsed && pass.verifiedAt != null)
              _DetailRow(label: 'Verified at', value: pass.verifiedAt!),
            if (_error != null) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                _error!,
                key: const Key('gate-pass-cancel-error'),
                style: text.bodySmall.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        // Plain hasPermission, NOT AksharaManageAction/AksharaApproveAction:
        // those guards only recognise permissions named `manage*`/`approve*`
        // (mutation_permission_validator.dart:19-23) and fail CLOSED otherwise,
        // so `verifyGatePass` would never render for anyone. Kept uniform across
        // the module so the gating does not silently depend on a slug's prefix.
        // See GatePassesScreen's class doc.
        if (pass.isCancellable && canCancel)
          FilledButton.tonal(
            key: const Key('gate-pass-cancel-button'),
            onPressed: _busy ? null : _cancel,
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel pass'),
          ),
        if (pass.isVerifiable && canVerify)
          FilledButton(
            key: const Key('gate-pass-open-verify-button'),
            onPressed: _busy ? null : _openVerify,
            child: const Text('Verify'),
          ),
      ],
    );
  }

  KpiAccent _toneFor(String status) => switch (status) {
        'used' => KpiAccent.success,
        'approved' => KpiAccent.success,
        'pending' => KpiAccent.neutral,
        'rejected' => KpiAccent.error,
        'expired' => KpiAccent.error,
        'cancelled' => KpiAccent.neutral,
        _ => KpiAccent.neutral,
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
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
          SizedBox(width: 120, child: Text(label, style: text.bodySmall)),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
