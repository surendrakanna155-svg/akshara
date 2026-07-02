import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_text.dart';
import '../../core/testing/qa_test_keys.dart';
import 'transport_models.dart';
import 'transport_mutations_provider.dart';
import 'transport_requests.dart';

/// TRN-1/TRN-2 — vehicle create/edit dialog with ISO date pickers for the five
/// document-expiry fields. Dates are ISO YYYY-MM-DD strings (never DateTime).
Future<void> showVehicleFormDialog(
  BuildContext context,
  WidgetRef ref, {
  TransportVehicle? vehicle,
}) async {
  final isEdit = vehicle != null;
  final registration = TextEditingController(text: vehicle?.registration ?? '');
  final model = TextEditingController(text: vehicle?.model ?? '');
  final capacity =
      TextEditingController(text: vehicle == null ? '' : '${vehicle.capacity}');
  var status = vehicle?.status ?? TransportVehicleStatus.active;
  final expiry = <String, String>{
    'insurance': vehicle?.insuranceExpiry ?? '',
    'fitness': vehicle?.fitnessExpiry ?? '',
    'puc': vehicle?.pucExpiry ?? '',
    'permit': vehicle?.permitExpiry ?? '',
    'roadTax': vehicle?.roadTaxExpiry ?? '',
  };

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(isEdit ? 'Edit vehicle' : 'Register vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: QaTestKeys.transportVehicleRegistrationField,
                controller: registration,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Registration',
                  hintText: 'e.g. TS 09 AB 4521',
                ),
              ),
              TextField(
                controller: model,
                decoration: const InputDecoration(labelText: 'Model (optional)'),
              ),
              TextField(
                key: QaTestKeys.transportVehicleCapacityField,
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TransportVehicleStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in TransportVehicleStatus.values)
                    DropdownMenuItem(value: s, child: Text(_vehicleStatusLabel(s))),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              const SizedBox(height: 8),
              _ExpiryDateField(
                label: 'Insurance expiry',
                value: expiry['insurance']!,
                onChanged: (v) => setState(() => expiry['insurance'] = v),
              ),
              _ExpiryDateField(
                label: 'Fitness expiry',
                value: expiry['fitness']!,
                onChanged: (v) => setState(() => expiry['fitness'] = v),
              ),
              _ExpiryDateField(
                label: 'PUC expiry',
                value: expiry['puc']!,
                onChanged: (v) => setState(() => expiry['puc'] = v),
              ),
              _ExpiryDateField(
                label: 'Permit expiry',
                value: expiry['permit']!,
                onChanged: (v) => setState(() => expiry['permit'] = v),
              ),
              _ExpiryDateField(
                label: 'Road tax expiry',
                value: expiry['roadTax']!,
                onChanged: (v) => setState(() => expiry['roadTax'] = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportVehicleDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isEdit ? 'Save' : 'Register'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) return;

  final reg = registration.text.trim();
  if (reg.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration is required.')),
    );
    return;
  }
  final cap = int.tryParse(capacity.text.trim()) ?? 0;

  try {
    final notifier = ref.read(vehicleMutationProvider.notifier);
    final result = isEdit
        ? await notifier.edit(
            UpdateTransportVehicleRequest(
              id: vehicle.id,
              registration: reg,
              model: model.text.trim(),
              capacity: cap,
              status: status,
              insuranceExpiry: expiry['insurance'],
              fitnessExpiry: expiry['fitness'],
              pucExpiry: expiry['puc'],
              permitExpiry: expiry['permit'],
              roadTaxExpiry: expiry['roadTax'],
            ),
          )
        : await notifier.create(
            CreateTransportVehicleRequest(
              registration: reg,
              model: model.text.trim(),
              capacity: cap,
              status: status,
              insuranceExpiry: expiry['insurance']!,
              fitnessExpiry: expiry['fitness']!,
              pucExpiry: expiry['puc']!,
              permitExpiry: expiry['permit']!,
              roadTaxExpiry: expiry['roadTax']!,
            ),
          );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportVehicleSavedSnackbar,
        content: Text('Vehicle ${result.registration} saved'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

/// TRN-1 — delete a vehicle (surfaces the referenced-in-use rejection).
Future<void> confirmDeleteVehicle(
  BuildContext context,
  WidgetRef ref,
  TransportVehicle vehicle,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete vehicle'),
      content: Text('Delete ${vehicle.registration}? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportVehicleDeleteConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(deleteVehicleProvider.notifier).execute(
          DeleteTransportVehicleRequest(id: vehicle.id),
        );
    final state = ref.read(deleteVehicleProvider);
    if (!context.mounted) return;
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(state.error!))),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportVehicleDeletedSnackbar,
        content: Text('Vehicle ${vehicle.registration} deleted'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

String _vehicleStatusLabel(TransportVehicleStatus status) => switch (status) {
      TransportVehicleStatus.active => 'Active',
      TransportVehicleStatus.maintenance => 'Maintenance',
      TransportVehicleStatus.retired => 'Retired',
    };

/// A read-only text field that opens a Material date picker and emits an ISO
/// YYYY-MM-DD string (empty when cleared).
class _ExpiryDateField extends StatelessWidget {
  const _ExpiryDateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final initial = _parse(value) ?? now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 10),
          );
          if (picked != null) onChanged(_iso(picked));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: value.isEmpty
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onChanged(''),
                  ),
          ),
          child: Text(value.isEmpty ? 'Not set' : value),
        ),
      ),
    );
  }

  static DateTime? _parse(String iso) {
    if (iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
