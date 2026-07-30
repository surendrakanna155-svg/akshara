import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/api/transport/v2/transport_v2_datasource.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../transport_v2_models.dart';
import '../transport_v2_providers.dart';

/// BUS-043/044/046/048/051/054 — assign a bus and driver, or substitute for a day.
///
/// THE OPERATION THAT DID NOT EXIST
///
/// Pre-v2 there was no way to put a bus or a driver on a route at all:
/// `assignedBus` was written `""` at creation and set by no endpoint, and
/// `assignedDriverId` was read by a delete-guard and written by nothing. That
/// single gap silently disabled the capacity guard (unlimited over-allocation of
/// a 48-seat bus) and both in-use delete guards.
///
/// TWO MODES, one sheet:
///   * PERMANENT — the standing arrangement. Replaces the previous one.
///   * SUBSTITUTE — a bounded override for specific dates that leaves the
///     permanent arrangement completely untouched (owner requirement 1). This is
///     what makes "Ramesh is on leave, Suresh drives Tuesday" an ordinary record.
///
/// The pickers show WHY someone cannot be chosen — expired insurance, expired
/// licence, on leave, already running another route — because a picker that
/// offers an invalid option and only fails on submit wastes the admin's time and
/// teaches them to ignore the error.
Future<void> showTransportV2AssignmentSheet(
  BuildContext context,
  WidgetRef ref, {
  required TransportRouteV2 route,
  bool substituteMode = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AssignmentDialog(
      route: route,
      substituteMode: substituteMode,
    ),
  );
}

class _AssignmentDialog extends ConsumerStatefulWidget {
  const _AssignmentDialog({required this.route, required this.substituteMode});

  final TransportRouteV2 route;
  final bool substituteMode;

  @override
  ConsumerState<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends ConsumerState<_AssignmentDialog> {
  String? _vehicleId;
  String? _driverId;
  late final TextEditingController _reason;
  DateTime? _from;
  DateTime? _to;
  bool _allowNonCompliant = false;
  bool _submitting = false;
  String? _formError;

  bool get _isSubstitute => widget.substituteMode;

  @override
  void initState() {
    super.initState();
    final current = widget.route.assignment;
    // Prefill from what is in force, so a driver-only change does not silently
    // drop the bus (and vice versa).
    _vehicleId = current?.vehicleId;
    _driverId = current?.driverId;
    _reason = TextEditingController();
    if (_isSubstitute) {
      final today = ref.read(transportV2ServiceDateProvider);
      _from = today;
      _to = today;
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isFrom}) async {
    final base = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        // Keep the range coherent rather than letting the admin submit an
        // inverted one the backend would reject.
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _formError = null);

    if (_vehicleId == null && _driverId == null) {
      setState(() => _formError = 'Choose a bus or a driver to assign.');
      return;
    }
    if (_isSubstitute && _reason.text.trim().isEmpty) {
      // An unexplained substitution is an unauditable one — six months later
      // nobody can say why the regular driver was off.
      setState(() => _formError = 'A reason is required for a substitution.');
      return;
    }

    setState(() => _submitting = true);
    final mutations = ref.read(transportV2MutationsProvider.notifier);

    int? tripsRebound;
    if (_isSubstitute) {
      final result = await mutations.substitute(
        routeId: widget.route.id,
        reason: _reason.text.trim(),
        vehicleId: _vehicleId,
        driverId: _driverId,
        effectiveFrom: _from == null ? null : _iso(_from!),
        effectiveTo: _to == null ? null : _iso(_to!),
        allowNonCompliant: _allowNonCompliant,
      );
      tripsRebound = result?.tripsRebound;
    } else {
      await mutations.setAssignment(
        routeId: widget.route.id,
        vehicleId: _vehicleId,
        driverId: _driverId,
        reason: _reason.text.trim(),
        allowNonCompliant: _allowNonCompliant,
      );
    }

    final state = ref.read(transportV2MutationsProvider);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (state.hasError) {
      final guidance = transportV2Guidance(state.errorCode);
      // COMPLIANCE_BLOCKED is recoverable by an explicit override, so offer it
      // in place rather than making the admin guess.
      setState(() {
        _formError = guidance.isNotEmpty ? guidance : state.failure!.message;
      });
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2SuccessSnackbar,
        content: Text(
          // Trip re-binding is the detail that decides whether the substitute
          // actually sees the trip on login. Report it, do not hide it.
          (tripsRebound ?? 0) > 0
              ? '${state.successMessage ?? 'Saved'} · '
                  "$tripsRebound already-scheduled trip(s) moved to the substitute"
              : state.successMessage ?? 'Saved',
        ),
      ),
    );
  }

  bool get _canOverride =>
      ref.read(transportV2MutationsProvider).errorCode ==
      TransportV2ErrorCodes.complianceBlocked;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(transportV2VehiclesProvider);
    final drivers = ref.watch(transportV2DriversProvider);

    return AlertDialog(
      key: QaTestKeys.transportV2AssignmentDialog,
      title: Text(
        _isSubstitute
            ? 'Substitute for ${widget.route.name}'
            : 'Assign bus & driver — ${widget.route.name}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSubstitute) ...[
              Text(
                'The permanent arrangement is not changed. It resumes '
                'automatically after the last date below.',
                key: QaTestKeys.transportV2SubstituteExplainer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: QaTestKeys.transportV2SubstituteFromField,
                      onPressed: () => _pickDate(isFrom: true),
                      child: Text('From: ${_from == null ? '—' : _iso(_from!)}'),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: OutlinedButton(
                      key: QaTestKeys.transportV2SubstituteToField,
                      onPressed: () => _pickDate(isFrom: false),
                      child: Text('To: ${_to == null ? '—' : _iso(_to!)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
            ],

            _VehiclePicker(
              async: vehicles,
              selected: _vehicleId,
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            _DriverPicker(
              async: drivers,
              selected: _driverId,
              onChanged: (v) => setState(() => _driverId = v),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.transportV2AssignmentReasonField,
              controller: _reason,
              decoration: InputDecoration(
                labelText: _isSubstitute ? 'Reason' : 'Note (optional)',
                hintText: _isSubstitute ? 'e.g. Ramesh on sick leave' : null,
              ),
            ),

            if (_formError != null) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                _formError!,
                key: QaTestKeys.transportV2AssignmentError,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.error),
              ),
              // The override is offered ONLY after the gate has actually
              // refused, so it can never be ticked pre-emptively out of habit.
              if (_canOverride)
                CheckboxListTile(
                  key: QaTestKeys.transportV2AllowNonCompliantCheckbox,
                  value: _allowNonCompliant,
                  onChanged: (v) =>
                      setState(() => _allowNonCompliant = v ?? false),
                  title: const Text('Assign anyway despite the expired document'),
                  subtitle: const Text('This override is recorded separately.'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
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
          key: QaTestKeys.transportV2AssignmentSubmitButton,
          onPressed: _submitting ? null : _submit,
          child: Text(_isSubstitute ? 'Assign substitute' : 'Save assignment'),
        ),
      ],
    );
  }
}

/// Shows every vehicle, but states why an ineligible one is ineligible.
///
/// Hiding blocked options would leave the admin wondering where the bus went;
/// showing them without a reason would let them pick one that then fails.
class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.async,
    required this.selected,
    required this.onChanged,
  });

  final AsyncValue<List<VehicleV2>> async;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Could not load buses.'),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return const Text('No buses registered yet. Add one first.');
        }
        return DropdownButtonFormField<String?>(
          key: QaTestKeys.transportV2AssignVehicleField,
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Bus'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('No bus')),
            for (final v in vehicles)
              DropdownMenuItem<String?>(
                value: v.id,
                child: Text(
                  [
                    v.label,
                    if (v.blockerLabel != null) '— ${v.blockerLabel}',
                    if (v.isCompliant && v.isCommitted)
                      '— already on ${v.assignedRouteName}',
                  ].join(' '),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _DriverPicker extends StatelessWidget {
  const _DriverPicker({
    required this.async,
    required this.selected,
    required this.onChanged,
  });

  final AsyncValue<List<DriverV2>> async;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Could not load drivers.'),
      data: (drivers) {
        if (drivers.isEmpty) {
          return const Text('No drivers registered yet. Add one first.');
        }
        return DropdownButtonFormField<String?>(
          key: QaTestKeys.transportV2AssignDriverField,
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Driver'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('No driver')),
            for (final d in drivers)
              DropdownMenuItem<String?>(
                value: d.id,
                child: Text(
                  [
                    d.name,
                    // "on leave" is the one an admin most needs to see: picking
                    // an unavailable driver is how a school arranges cover and
                    // still has nobody to drive.
                    if (d.blockerLabel != null) '— ${d.blockerLabel}',
                    if (d.isAssignable && d.isCommitted)
                      '— already on ${d.assignedRouteName}',
                  ].join(' '),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
