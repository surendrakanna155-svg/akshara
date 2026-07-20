import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../gate_pass_datasource.dart';
import '../gate_pass_models.dart';
import '../gate_pass_providers.dart';

/// The gate check: staff TYPES IN the OTP the parent presents (never shown,
/// requested from the API, or logged by this app — the server dispatches it
/// directly to the guardian). Success shows the child + pickup person so
/// staff can visually match them before releasing the child. Failure is a
/// single generic message — never which check failed (status/expiry/wrong
/// code all look identical here, deliberately, so a prober learns nothing).
class GatePassVerifyDialog extends ConsumerStatefulWidget {
  const GatePassVerifyDialog({super.key, required this.gatePass});

  final GatePass gatePass;

  @override
  ConsumerState<GatePassVerifyDialog> createState() => _GatePassVerifyDialogState();
}

class _GatePassVerifyDialogState extends ConsumerState<GatePassVerifyDialog> {
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;
  GatePass? _verified;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final otp = _otp.text.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Enter the code the parent presented.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verified =
          await ref.read(gatePassDataSourceProvider).verify(widget.gatePass.id, otp: otp);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _verified = verified;
      });
    } on GatePassVerificationRejected {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = GatePassVerificationRejected.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not verify right now. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = _verified;
    return AlertDialog(
      key: const Key('gate-pass-verify-dialog'),
      title: const Text('Verify gate pass'),
      content: SizedBox(
        width: 380,
        child: verified == null ? _buildEntryForm(context) : _buildResult(context, verified),
      ),
      actions: verified == null
          ? [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('gate-pass-verify-submit-button'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
            ]
          : [
              FilledButton(
                key: const Key('gate-pass-verify-done-button'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done'),
              ),
            ],
    );
  }

  Widget _buildEntryForm(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${gatePassTypeLabel(widget.gatePass.passType)} · Student ${widget.gatePass.studentId}',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          key: const Key('gate-pass-verify-otp-field'),
          controller: _otp,
          enabled: !_busy,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Code presented by parent'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            _error!,
            key: const Key('gate-pass-verify-error'),
            style: text.bodySmall.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context, GatePass verified) {
    final text = context.aksharaText;
    return Column(
      key: const Key('gate-pass-verify-result'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AksharaSpacing.s2),
            const Expanded(child: Text('Verified — match before releasing the child')),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        Text('Child', style: text.bodySmall),
        Text(verified.studentId, style: text.titleMedium),
        const SizedBox(height: AksharaSpacing.s3),
        Text('Pickup person', style: text.bodySmall),
        Text(verified.pickupPersonName, style: text.titleMedium),
        Text(
          '${verified.pickupPersonRelation} · ${verified.pickupPersonPhone}',
          style: text.bodyMedium,
        ),
      ],
    );
  }
}
