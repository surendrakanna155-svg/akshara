import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/forms/akshara_searchable_dropdown.dart';
import '../../../theme/theme_extensions.dart';
import '../gate_pass_datasource.dart';
import '../gate_pass_models.dart';
import '../gate_pass_providers.dart';

/// Raise a gate pass (requestGatePass). The FAB that opens this is already
/// gated by [AksharaManageAction] in the screen.
class GatePassRaiseDialog extends ConsumerStatefulWidget {
  const GatePassRaiseDialog({super.key});

  @override
  ConsumerState<GatePassRaiseDialog> createState() => _GatePassRaiseDialogState();
}

class _GatePassRaiseDialogState extends ConsumerState<GatePassRaiseDialog> {
  final _studentId = TextEditingController();
  final _reason = TextEditingController();
  final _pickupName = TextEditingController();
  final _pickupRelation = TextEditingController();
  final _pickupPhone = TextEditingController();
  String _passType = gatePassTypes.first;
  DateTime _scheduledAt = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _studentId.dispose();
    _reason.dispose();
    _pickupName.dispose();
    _pickupRelation.dispose();
    _pickupPhone.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final studentId = _studentId.text.trim();
    final pickupName = _pickupName.text.trim();
    final pickupRelation = _pickupRelation.text.trim();
    final pickupPhone = _pickupPhone.text.trim();
    if (studentId.isEmpty) {
      setState(() => _error = 'Enter the student ID.');
      return;
    }
    if (pickupName.isEmpty || pickupRelation.isEmpty || pickupPhone.isEmpty) {
      setState(() => _error = 'Enter the pickup person\'s name, relation, and phone.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(gatePassDataSourceProvider).raise(
            studentId: studentId,
            passType: _passType,
            reason: _reason.text.trim(),
            pickupPersonName: pickupName,
            pickupPersonRelation: pickupRelation,
            pickupPersonPhone: pickupPhone,
            scheduledAt: _scheduledAt,
          );
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
        _error = 'Could not send the request. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return AlertDialog(
      key: const Key('gate-pass-raise-dialog'),
      title: const Text('Raise gate pass'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('gate-pass-student-id-field'),
              controller: _studentId,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: 12),
            AksharaSearchableDropdown(
              label: 'Pass type',
              value: gatePassTypeLabel(_passType),
              options: [for (final t in gatePassTypes) gatePassTypeLabel(t)],
              enabled: !_busy,
              onChanged: (label) {
                final match = gatePassTypes.firstWhere(
                  (t) => gatePassTypeLabel(t) == label,
                  orElse: () => gatePassTypes.first,
                );
                setState(() => _passType = match);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('gate-pass-reason-field'),
              controller: _reason,
              enabled: !_busy,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const Key('gate-pass-scheduled-at-field'),
              onTap: _busy ? null : _pickScheduledAt,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Scheduled at',
                  suffixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(_formatScheduledAt(_scheduledAt)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pickup person', style: text.titleSmall),
            const SizedBox(height: 8),
            TextField(
              key: const Key('gate-pass-pickup-name-field'),
              controller: _pickupName,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('gate-pass-pickup-relation-field'),
              controller: _pickupRelation,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Relation to student'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('gate-pass-pickup-phone-field'),
              controller: _pickupPhone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('gate-pass-raise-error'),
                style: text.bodySmall.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('gate-pass-submit-button'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Raise pass'),
        ),
      ],
    );
  }
}

String _formatScheduledAt(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}
