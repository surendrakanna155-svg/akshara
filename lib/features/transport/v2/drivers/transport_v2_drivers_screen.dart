import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/permissions.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../transport_models.dart' show TransportScreen;
import '../../widgets/transport_module_scaffold.dart';
import '../transport_v2_models.dart';
import '../transport_v2_providers.dart';

/// BUS-050 — driver roster and availability.
///
/// WHY AVAILABILITY IS THE LOAD-BEARING FEATURE HERE
///
/// The owner's substitute-driver requirement starts with the system KNOWING the
/// regular driver is unavailable. Pre-v2 a driver had only a coarse `status`
/// field — no dates — so there was no way to express "Ramesh is off Tuesday to
/// Thursday" and therefore no way to know a route would be unstaffed tomorrow.
/// The gap surfaced when a bus failed to arrive.
///
/// Marking leave here immediately answers the question that matters: WHICH ROUTES
/// does this leave uncover? Those are returned by the write itself, so the admin
/// is told at the moment of recording rather than having to go looking.
class TransportV2DriversScreen extends ConsumerWidget {
  const TransportV2DriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(transportV2EnabledProvider);
    final driversAsync = ref.watch(transportV2DriversProvider);
    final date = ref.watch(transportV2ServiceDateIsoProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.drivers,
      showFilterBar: false,
      body: !enabled
          ? const Padding(
              padding: EdgeInsets.all(AksharaSpacing.s4),
              child: AksharaEmptyState(
                key: QaTestKeys.transportV2NotEnabledState,
                title: 'Transport v2 is not enabled for this school',
                message: 'Drivers become available once this school is migrated.',
                icon: Icons.person_outline,
              ),
            )
          : driversAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
                child: AksharaLoadingState(semanticLabel: 'Loading drivers'),
              ),
              error: (_, __) => AksharaErrorState(
                message: 'Unable to load drivers.',
                onRetry: () => ref.invalidate(transportV2DriversProvider),
              ),
              data: (drivers) => _DriversBody(drivers: drivers, serviceDate: date),
            ),
    );
  }
}

class _DriversBody extends ConsumerWidget {
  const _DriversBody({required this.drivers, required this.serviceDate});

  final List<DriverV2> drivers;
  final String serviceDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (drivers.isEmpty) {
      return const AksharaEmptyState(
        message: 'No drivers registered yet.',
        icon: Icons.person_outline,
      );
    }

    // Whoever cannot drive today comes first — that is the admin's work list.
    final blocked = drivers.where((d) => !d.isAssignable).toList(growable: false);
    final available = drivers.where((d) => d.isAssignable).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Availability shown for $serviceDate',
          style: context.aksharaText.bodySmall
              .copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AksharaSpacing.s3),
        if (blocked.isNotEmpty) ...[
          AksharaSurfaceCard(
            key: QaTestKeys.transportV2DriversBlockedBanner,
            child: Row(
              children: [
                Icon(Icons.person_off_outlined,
                    color: context.colors.error, size: 20),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Text(
                    '${blocked.length} driver${blocked.length == 1 ? '' : 's'} '
                    'cannot drive on this date. Any route they hold needs a '
                    'substitute.',
                    style: context.aksharaText.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AksharaSpacing.s3),
        ],
        for (final d in [...blocked, ...available]) ...[
          _DriverCard(driver: d),
          const SizedBox(height: AksharaSpacing.s3),
        ],
      ],
    );
  }
}

class _DriverCard extends ConsumerWidget {
  const _DriverCard({required this.driver});

  final DriverV2 driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return AksharaSurfaceCard(
      key: QaTestKeys.transportV2DriverCard(driver.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(driver.name, style: text.titleMedium)),
              if (driver.blockerLabel != null)
                AksharaStatusChip(
                  key: QaTestKeys.transportV2DriverBlockerChip(driver.id),
                  label: driver.blockerLabel!,
                  tone: KpiAccent.error,
                ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            [
              if (driver.licenceNumber.isNotEmpty) driver.licenceNumber,
              if (driver.phone.isNotEmpty) driver.phone,
            ].join(' · '),
            style: text.bodySmall,
          ),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            driver.isCommitted
                ? 'Runs ${driver.assignedRouteName}'
                : 'No route assigned',
            style: text.bodySmall
                .copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          AksharaManageAction(
            permission: Permission.manageTransport,
            child: OutlinedButton.icon(
              key: QaTestKeys.transportV2MarkLeaveButton(driver.id),
              onPressed: () => _markLeave(context, ref),
              icon: const Icon(Icons.event_busy_outlined, size: 18),
              label: const Text('Record leave'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markLeave(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_LeaveRequest>(
      context: context,
      builder: (context) => _LeaveDialog(driverName: driver.name),
    );
    if (result == null || !context.mounted) return;

    final affected =
        await ref.read(transportV2MutationsProvider.notifier).setDriverAvailability(
              driverId: driver.id,
              fromDate: result.from,
              toDate: result.to,
              kind: result.kind,
              reason: result.reason,
            );
    if (!context.mounted) return;

    final state = ref.read(transportV2MutationsProvider);
    if (state.hasError) {
      final guidance = transportV2Guidance(state.errorCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.transportV2ErrorSnackbar,
          content: Text(guidance.isNotEmpty ? guidance : state.failure!.message),
        ),
      );
      return;
    }

    // THE POINT OF THIS FEATURE: the admin is told which routes are now
    // uncovered, at the moment of recording, rather than discovering it when a
    // bus fails to arrive.
    if ((affected ?? const []).isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: QaTestKeys.transportV2UncoveredRoutesDialog,
          title: const Text('These routes now need a substitute'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in affected!)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                  child: Text('• ${r.routeName}'),
                ),
              const SizedBox(height: AksharaSpacing.s2),
              const Text(
                'Use Substitute on each route to cover these dates. The '
                'permanent assignment stays as it is.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2SuccessSnackbar,
        content: Text(
          '${state.successMessage ?? 'Leave recorded'} · no routes affected',
        ),
      ),
    );
  }
}

class _LeaveRequest {
  const _LeaveRequest(this.from, this.to, this.kind, this.reason);
  final String from;
  final String to;
  final String kind;
  final String reason;
}

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({required this.driverName});

  final String driverName;

  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  late DateTime _from;
  late DateTime _to;
  String _kind = 'leave';
  late final TextEditingController _reason;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = _from;
    _reason = TextEditingController();
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

  Future<void> _pick({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        // Keep the range coherent rather than letting an inverted one reach the
        // backend only to be rejected.
        if (_to.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: QaTestKeys.transportV2LeaveDialog,
      title: Text('Record leave — ${widget.driverName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: QaTestKeys.transportV2LeaveFromField,
                  onPressed: () => _pick(isFrom: true),
                  child: Text('From: ${_iso(_from)}'),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: OutlinedButton(
                  key: QaTestKeys.transportV2LeaveToField,
                  onPressed: () => _pick(isFrom: false),
                  child: Text('To: ${_iso(_to)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            key: QaTestKeys.transportV2LeaveKindField,
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Kind'),
            items: const [
              DropdownMenuItem(value: 'leave', child: Text('Leave')),
              DropdownMenuItem(value: 'sick', child: Text('Sick')),
              DropdownMenuItem(value: 'rest', child: Text('Rest day')),
              DropdownMenuItem(value: 'training', child: Text('Training')),
              DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            key: QaTestKeys.transportV2LeaveReasonField,
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(_error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportV2LeaveSubmitButton,
          onPressed: () {
            if (_to.isBefore(_from)) {
              setState(() => _error = 'The end date cannot be before the start.');
              return;
            }
            Navigator.of(context).pop(
              _LeaveRequest(_iso(_from), _iso(_to), _kind, _reason.text.trim()),
            );
          },
          child: const Text('Record'),
        ),
      ],
    );
  }
}
