import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../transport_v2_models.dart';
import '../transport_v2_providers.dart';

/// BUS-033/035 — route create & edit.
///
/// Replaces a dialog with ONE field ("Route name") that silently hardcoded
/// distance, both departure times and the shift — values that, because no update
/// endpoint existed, were then permanently uncorrectable.
///
/// Two rules this form enforces:
///   1. nothing is hidden. Every persisted attribute is visible and editable.
///   2. an untouched field is not submitted, so the backend leaves it alone.
///      Submitting a field the form never loaded is exactly how the legacy stop
///      editor silently erased drop times (BUS-007).
Future<void> showTransportV2RouteForm(
  BuildContext context,
  WidgetRef ref, {
  TransportRouteV2? route,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RouteFormDialog(route: route),
  );
}

class _RouteFormDialog extends ConsumerStatefulWidget {
  const _RouteFormDialog({this.route});

  final TransportRouteV2? route;

  @override
  ConsumerState<_RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends ConsumerState<_RouteFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _distanceKm;

  late RouteV2Shift _shift;
  late RouteV2Direction _direction;
  StopTime? _departure;
  StopTime? _returnTime;

  String? _nameError;
  bool _submitting = false;

  bool get _isEdit => widget.route != null;

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _name = TextEditingController(text: r?.name ?? '');
    _code = TextEditingController(text: r?.code ?? '');
    _distanceKm = TextEditingController(
      text: r?.distanceM == null ? '' : (r!.distanceM! / 1000).toStringAsFixed(1),
    );
    _shift = r?.shift ?? RouteV2Shift.am;
    _direction = r?.direction ?? RouteV2Direction.pickup;
    // Prefill BOTH times from the persisted route — never blank on edit.
    _departure = r?.defaultDepartureTime;
    _returnTime = r?.defaultReturnTime;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _distanceKm.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool departure}) async {
    final current = departure ? _departure : _returnTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay(hour: departure ? 7 : 15, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    setState(() {
      final value = StopTime(picked.hour * 60 + picked.minute);
      if (departure) {
        _departure = value;
      } else {
        _returnTime = value;
      }
    });
  }

  int? _distanceMeters() {
    final raw = _distanceKm.text.trim();
    if (raw.isEmpty) return null;
    final km = double.tryParse(raw);
    if (km == null || km < 0) return null;
    return (km * 1000).round();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Route name is required');
      return;
    }
    if (_distanceKm.text.trim().isNotEmpty && _distanceMeters() == null) {
      setState(() => _nameError = null);
      _snack('Distance must be a number in kilometres.');
      return;
    }

    setState(() => _submitting = true);
    final mutations = ref.read(transportV2MutationsProvider.notifier);

    if (_isEdit) {
      await mutations.updateRoute(
        routeId: widget.route!.id,
        name: _name.text.trim(),
        code: _code.text.trim(),
        shift: _shift,
        direction: _direction,
        // Only send a time the form actually holds. A null stays null, so the
        // backend leaves the stored value untouched.
        defaultDepartureTime: _departure,
        defaultReturnTime: _returnTime,
        distanceM: _distanceMeters(),
      );
    } else {
      await mutations.createRoute(
        name: _name.text.trim(),
        shift: _shift,
        direction: _direction,
        code: _code.text.trim(),
        defaultDepartureTime: _departure,
        defaultReturnTime: _returnTime,
        distanceM: _distanceMeters(),
      );
    }

    final state = ref.read(transportV2MutationsProvider);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (state.hasError) {
      final guidance = transportV2Guidance(state.errorCode);
      _snack(guidance.isNotEmpty ? guidance : state.failure!.message);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2SuccessSnackbar,
        content: Text(state.successMessage ?? 'Saved'),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2ErrorSnackbar,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: QaTestKeys.transportV2RouteFormDialog,
      title: Text(_isEdit ? 'Edit route' : 'New route'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: QaTestKeys.transportV2RouteNameField,
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Route name',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.transportV2RouteCodeField,
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Route code (optional)',
                hintText: 'e.g. R12',
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),

            // Shift and direction are CHOICES, not hidden defaults. A route is
            // one shift in v2 — the legacy 'both' value made AM/PM
            // indistinguishable and blocked independent assignment.
            DropdownButtonFormField<RouteV2Shift>(
              key: QaTestKeys.transportV2RouteShiftField,
              initialValue: _shift,
              decoration: const InputDecoration(labelText: 'Shift'),
              items: const [
                DropdownMenuItem(
                    value: RouteV2Shift.am, child: Text('Morning (AM)')),
                DropdownMenuItem(
                    value: RouteV2Shift.pm, child: Text('Afternoon (PM)')),
              ],
              onChanged: (v) => setState(() => _shift = v ?? _shift),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            DropdownButtonFormField<RouteV2Direction>(
              key: QaTestKeys.transportV2RouteDirectionField,
              initialValue: _direction,
              decoration: const InputDecoration(labelText: 'Direction'),
              items: const [
                DropdownMenuItem(
                    value: RouteV2Direction.pickup,
                    child: Text('Pickup (home → school)')),
                DropdownMenuItem(
                    value: RouteV2Direction.drop,
                    child: Text('Drop (school → home)')),
              ],
              onChanged: (v) => setState(() => _direction = v ?? _direction),
            ),
            const SizedBox(height: AksharaSpacing.s3),

            // BUS-038 — a real time picker. Free text is not offered at all, so
            // the "7.05"/"morning" class of value cannot be entered.
            _TimeRow(
              fieldKey: QaTestKeys.transportV2RouteDepartureField,
              label: 'Default departure',
              value: _departure,
              onPick: () => _pickTime(departure: true),
              onClear: () => setState(() => _departure = null),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            _TimeRow(
              fieldKey: QaTestKeys.transportV2RouteReturnField,
              label: 'Default return',
              value: _returnTime,
              onPick: () => _pickTime(departure: false),
              onClear: () => setState(() => _returnTime = null),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.transportV2RouteDistanceField,
              controller: _distanceKm,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Distance (km, optional)',
                hintText: 'e.g. 14.2',
              ),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                'The route is created as a draft. It can carry students once a '
                'bus, a driver and located stops are set.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportV2RouteFormSubmitButton,
          onPressed: _submitting ? null : _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final Key fieldKey;
  final String label;
  final StopTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: fieldKey,
            onPressed: onPick,
            icon: const Icon(Icons.schedule_outlined, size: 18),
            // "Not set" is an honest state, distinct from a fabricated default.
            label: Text('$label: ${value?.toDisplay() ?? 'Not set'}'),
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: 'Clear $label',
            icon: const Icon(Icons.clear, size: 18),
            onPressed: onClear,
          ),
      ],
    );
  }
}
