import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_text.dart';
import '../../core/testing/qa_test_keys.dart';
import 'transport_models.dart';
import 'transport_mutations_provider.dart';
import 'transport_requests.dart';

/// TRN-1/TRN-2 — driver create/edit dialog with an ISO licence-expiry picker.
Future<void> showDriverFormDialog(
  BuildContext context,
  WidgetRef ref, {
  TransportDriver? driver,
}) async {
  final isEdit = driver != null;
  final name = TextEditingController(text: driver?.name ?? '');
  final license = TextEditingController(text: driver?.licenseNumber ?? '');
  final phone = TextEditingController(text: driver?.phone ?? '');
  var status = driver?.status ?? TransportDriverStatus.active;
  var licenseExpiry = driver?.licenseExpiry ?? '';

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(isEdit ? 'Edit driver' : 'Add driver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: QaTestKeys.transportDriverNameField,
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                key: QaTestKeys.transportDriverLicenseField,
                controller: license,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Licence number'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TransportDriverStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in TransportDriverStatus.values)
                    DropdownMenuItem(value: s, child: Text(_driverStatusLabel(s))),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              const SizedBox(height: 8),
              _LicenceExpiryField(
                value: licenseExpiry,
                onChanged: (v) => setState(() => licenseExpiry = v),
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
            key: QaTestKeys.transportDriverDialogSubmitButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) return;

  final driverName = name.text.trim();
  final licence = license.text.trim();
  if (driverName.isEmpty || licence.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name and licence number are required.')),
    );
    return;
  }

  try {
    final notifier = ref.read(driverMutationProvider.notifier);
    final result = isEdit
        ? await notifier.edit(
            UpdateTransportDriverRequest(
              id: driver.id,
              name: driverName,
              licenseNumber: licence,
              phone: phone.text.trim(),
              status: status,
              licenseExpiry: licenseExpiry,
            ),
          )
        : await notifier.create(
            CreateTransportDriverRequest(
              name: driverName,
              licenseNumber: licence,
              phone: phone.text.trim(),
              status: status,
              licenseExpiry: licenseExpiry,
            ),
          );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportDriverSavedSnackbar,
        content: Text('Driver ${result.name} saved'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

/// TRN-1 — delete a driver (surfaces the referenced-in-use rejection).
Future<void> confirmDeleteDriver(
  BuildContext context,
  WidgetRef ref,
  TransportDriver driver,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete driver'),
      content: Text('Delete ${driver.name}? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportDriverDeleteConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(deleteDriverProvider.notifier).execute(
          DeleteTransportDriverRequest(id: driver.id),
        );
    final state = ref.read(deleteDriverProvider);
    if (!context.mounted) return;
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(state.error!))),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportDriverDeletedSnackbar,
        content: Text('Driver ${driver.name} deleted'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
  }
}

String _driverStatusLabel(TransportDriverStatus status) => switch (status) {
      TransportDriverStatus.active => 'Active',
      TransportDriverStatus.onLeave => 'On leave',
      TransportDriverStatus.inactive => 'Inactive',
    };

class _LicenceExpiryField extends StatelessWidget {
  const _LicenceExpiryField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final initial = value.isEmpty ? now : (DateTime.tryParse(value) ?? now);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 15),
        );
        if (picked != null) {
          onChanged('${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}');
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Licence expiry',
          suffixIcon: value.isEmpty
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(''),
                ),
        ),
        child: Text(value.isEmpty ? 'Not set' : value),
      ),
    );
  }
}
