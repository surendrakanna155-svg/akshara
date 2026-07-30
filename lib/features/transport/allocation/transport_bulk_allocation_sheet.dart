import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../transport_models.dart';
import '../transport_mutations_provider.dart';
import '../transport_requests.dart';

/// TRN-5 — bulk student→route allocation by class/section. Opens as a modal.
Future<void> showBulkAllocationSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<TransportRoute> routes,
}) async {
  final selectable =
      routes.where((r) => r.status == TransportRouteStatus.active).toList();
  if (selectable.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No active routes available to allocate.')),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _BulkAllocationForm(routes: selectable),
    ),
  );
}

class _BulkAllocationForm extends ConsumerStatefulWidget {
  const _BulkAllocationForm({required this.routes});

  final List<TransportRoute> routes;

  @override
  ConsumerState<_BulkAllocationForm> createState() =>
      _BulkAllocationFormState();
}

class _BulkAllocationFormState extends ConsumerState<_BulkAllocationForm> {
  late String _routeId;
  String? _className;
  String? _section;
  final _pickup = TextEditingController();
  final _drop = TextEditingController(text: 'NIKSHA Main Gate');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _routeId = widget.routes.first.id;
  }

  @override
  void dispose() {
    _pickup.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classOptionsProvider);
    final sections = _className == null
        ? const <String>[]
        : ref.watch(sectionOptionsForClassProvider(_className!));
    _className ??= classes.isNotEmpty ? classes.first : null;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bulk allocate to route', style: text.titleMedium),
          const SizedBox(height: AksharaSpacing.s4),
          DropdownButtonFormField<String>(
            initialValue: _routeId,
            decoration: const InputDecoration(labelText: 'Route'),
            items: [
              for (final r in widget.routes)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() => _routeId = v ?? _routeId),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            initialValue: classes.contains(_className) ? _className : null,
            decoration: const InputDecoration(labelText: 'Class'),
            items: [
              for (final c in classes)
                DropdownMenuItem(value: c, child: Text('Class $c')),
            ],
            onChanged: (v) => setState(() {
              _className = v;
              _section = null;
            }),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            initialValue: sections.contains(_section) ? _section : null,
            decoration: const InputDecoration(labelText: 'Section (optional)'),
            items: [
              for (final s in sections)
                DropdownMenuItem(value: s, child: Text('Section $s')),
            ],
            onChanged: (v) => setState(() => _section = v),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            controller: _pickup,
            decoration: const InputDecoration(labelText: 'Pickup stop'),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            controller: _drop,
            decoration: const InputDecoration(labelText: 'Drop stop'),
          ),
          const SizedBox(height: AksharaSpacing.s5),
          FilledButton(
            key: QaTestKeys.transportBulkAllocateSubmitButton,
            onPressed: _busy ? null : () => _submit(allowOverCapacity: false),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Allocate students'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit({required bool allowOverCapacity}) async {
    final className = _className;
    if (className == null) {
      _snack('Select a class to allocate.');
      return;
    }
    final pickup = _pickup.text.trim();
    final drop = _drop.text.trim();
    if (pickup.isEmpty || drop.isEmpty) {
      _snack('Pickup and drop stops are required.');
      return;
    }

    setState(() => _busy = true);
    final request = BulkAllocateTransportRequest(
      routeId: _routeId,
      pickupStop: pickup,
      dropStop: drop,
      className: className,
      sectionName: _section,
      allowOverCapacity: allowOverCapacity,
    );

    try {
      final result = await ref
          .read(bulkAllocateTransportProvider.notifier)
          .execute(request);
      if (!mounted) return;
      setState(() => _busy = false);

      final state = ref.read(bulkAllocateTransportProvider);
      if (state.hasError) {
        final error = state.error;
        if (error is ApiFailureException &&
            error.failure.code == 'CAPACITY_EXCEEDED' &&
            !allowOverCapacity) {
          final override = await _confirmOverCapacity();
          if (override == true && mounted) {
            await _submit(allowOverCapacity: true);
          }
          return;
        }
        _snack(aksharaErrorMessage(error ?? 'Bulk allocation failed.'));
        return;
      }
      if (result == null) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.transportBulkAllocateSuccessSnackbar,
          content: Text(
            'Allocated ${result.assignedCount}'
            '${result.skippedCount > 0 ? ', skipped ${result.skippedCount}' : ''}'
            '${result.capacityOverridden ? ' (over capacity)' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(aksharaErrorMessage(error));
    }
  }

  Future<bool?> _confirmOverCapacity() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Route over capacity'),
        content: const Text(
          'This route is over its vehicle capacity. Allocate anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportCapacityOverrideConfirmButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allocate anyway'),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
