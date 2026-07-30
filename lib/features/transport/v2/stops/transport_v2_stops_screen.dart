import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/api/transport/v2/transport_v2_datasource.dart';
import '../../../../core/repositories/api/transport/v2/transport_v2_repository.dart';
import '../../../../core/security/permissions.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../transport_models.dart' show TransportScreen;
import '../../widgets/transport_module_scaffold.dart';
import '../transport_v2_models.dart';
import '../transport_v2_providers.dart';

/// BUS-036/037/038/039/040 — school-level stop manager.
///
/// Stops are school-owned, not route-owned, so ONE physical "Green Park Gate"
/// serves both the morning and afternoon route (BUS-040). Pre-v2 stops were a
/// nested JSON array inside each route, so the same gate existed twice and
/// correcting its location fixed only one of them.
///
/// COORDINATE ENTRY — and the one thing still blocked.
///
/// A stop cannot be created without a location: that is the gating requirement
/// for the whole tracking feature, and (0,0) is rejected explicitly because it
/// is the exact value the legacy write path produced for every stop.
///
/// The MAP PICKER is blocked on BUS-086 (map SDK + API keys, owner-gated). So
/// this screen offers precise manual entry now — latitude/longitude with live
/// validation, plus address and landmark text — and leaves an explicit seam for
/// the pin. That is a deliberate choice over shipping nothing: an admin with a
/// coordinate from any source can configure a working route today, and the
/// pin-drop becomes a nicer input over the same validated field rather than a
/// new data path.
class TransportV2StopsScreen extends ConsumerWidget {
  const TransportV2StopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(transportV2EnabledProvider);
    final stopsAsync = ref.watch(transportV2StopsProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.routes,
      showFilterBar: false,
      body: !enabled
          ? const Padding(
              padding: EdgeInsets.all(AksharaSpacing.s4),
              child: AksharaEmptyState(
                key: QaTestKeys.transportV2NotEnabledState,
                title: 'Transport v2 is not enabled for this school',
                message: 'Stops become available once this school is migrated.',
                icon: Icons.place_outlined,
              ),
            )
          : stopsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
                child: AksharaLoadingState(semanticLabel: 'Loading stops'),
              ),
              error: (_, __) => AksharaErrorState(
                message: 'Unable to load transport stops.',
                onRetry: () => ref.invalidate(transportV2StopsProvider),
              ),
              data: (result) => _StopsBody(result: result),
            ),
    );
  }
}

class _StopsBody extends ConsumerWidget {
  const _StopsBody({required this.result});

  final StopsResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsLocation =
        result.stops.where((s) => s.needsLocation).toList(growable: false);
    final located =
        result.stops.where((s) => !s.needsLocation).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.isStale)
          Padding(
            padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
            child: AksharaSurfaceCard(
              key: QaTestKeys.transportV2StaleBanner,
              child: Text(
                'Showing saved data — could not reach the server.',
                style: context.aksharaText.bodySmall,
              ),
            ),
          ),

        // BUS-030 — migration debt, made loud. These stops came from the legacy
        // model with no coordinate; nothing invented one for them, and each
        // blocks its routes from being published until an admin places it.
        if (needsLocation.isNotEmpty) _NeedsLocationBanner(stops: needsLocation),

        Align(
          alignment: Alignment.centerRight,
          child: AksharaManageAction(
            permission: Permission.manageTransport,
            child: FilledButton.icon(
              key: QaTestKeys.transportV2CreateStopButton,
              onPressed: () => showTransportV2StopForm(context, ref),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('New stop'),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s4),

        if (result.stops.isEmpty)
          const AksharaEmptyState(
            message:
                'No stops yet. Create the stops your routes will use — each one '
                'needs a location before a route can go live.',
            icon: Icons.place_outlined,
          )
        else ...[
          for (final stop in needsLocation) ...[
            _StopCard(stop: stop),
            const SizedBox(height: AksharaSpacing.s3),
          ],
          for (final stop in located) ...[
            _StopCard(stop: stop),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      ],
    );
  }
}

class _NeedsLocationBanner extends StatelessWidget {
  const _NeedsLocationBanner({required this.stops});

  final List<TransportStopV2> stops;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: AksharaSurfaceCard(
        key: QaTestKeys.transportV2NeedsLocationBanner,
        child: Row(
          children: [
            Icon(Icons.wrong_location_outlined,
                color: context.colors.error, size: 20),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Text(
                '${stops.length} stop${stops.length == 1 ? '' : 's'} '
                'ha${stops.length == 1 ? 's' : 've'} no location. '
                'Routes using them cannot go live until each one is placed.',
                style: context.aksharaText.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopCard extends ConsumerWidget {
  const _StopCard({required this.stop});

  final TransportStopV2 stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final location = stop.location;

    return AksharaSurfaceCard(
      key: QaTestKeys.transportV2StopCard(stop.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(stop.name, style: text.titleMedium)),
              if (stop.needsLocation)
                AksharaStatusChip(
                  key: QaTestKeys.transportV2NeedsLocationChip(stop.id),
                  label: 'No location',
                  tone: KpiAccent.error,
                ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          if (location == null)
            Text(
              'Location not set — place this stop before adding it to a route',
              style: text.bodySmall.copyWith(color: context.colors.error),
            )
          else
            Text(
              '${location.latitude.toStringAsFixed(5)}, '
              '${location.longitude.toStringAsFixed(5)} · '
              'geofence ${stop.geofenceRadiusM} m',
              style: text.bodySmall,
            ),
          if (stop.addressText.isNotEmpty || stop.landmark.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              [stop.addressText, stop.landmark]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: text.bodySmall
                  .copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AksharaSpacing.s3),
          AksharaManageAction(
            permission: Permission.manageTransport,
            child: Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                OutlinedButton.icon(
                  key: QaTestKeys.transportV2EditStopButton(stop.id),
                  onPressed: () =>
                      showTransportV2StopForm(context, ref, stop: stop),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(stop.needsLocation ? 'Set location' : 'Edit'),
                ),
                OutlinedButton.icon(
                  key: QaTestKeys.transportV2DeleteStopButton(stop.id),
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${stop.name}?'),
        content: const Text(
          'A stop used by any route or student allocation cannot be deleted — '
          'detach it from its routes first. Because stops are shared, this may '
          'affect more than one route.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.transportV2DeleteStopConfirmButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(transportV2MutationsProvider.notifier).deleteStop(stop.id);
    if (!context.mounted) return;
    final state = ref.read(transportV2MutationsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (state.hasError) {
      final guidance = transportV2Guidance(state.errorCode);
      messenger.showSnackBar(
        SnackBar(
          key: QaTestKeys.transportV2ErrorSnackbar,
          content: Text(guidance.isNotEmpty ? guidance : state.failure!.message),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2SuccessSnackbar,
        content: Text(state.successMessage ?? 'Stop deleted'),
      ),
    );
  }
}

// ─── Stop form ───────────────────────────────────────────────────────────────

Future<void> showTransportV2StopForm(
  BuildContext context,
  WidgetRef ref, {
  TransportStopV2? stop,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _StopFormDialog(stop: stop),
  );
}

class _StopFormDialog extends ConsumerStatefulWidget {
  const _StopFormDialog({this.stop});

  final TransportStopV2? stop;

  @override
  ConsumerState<_StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends ConsumerState<_StopFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _address;
  late final TextEditingController _landmark;
  late int _radius;

  String? _nameError;
  String? _locationError;
  bool _submitting = false;

  bool get _isEdit => widget.stop != null;

  @override
  void initState() {
    super.initState();
    final s = widget.stop;
    final loc = s?.location;
    _name = TextEditingController(text: s?.name ?? '');
    // Prefill from the persisted stop — a form that submits what it never loaded
    // is how BUS-007's erasure happened.
    _lat = TextEditingController(
        text: loc == null ? '' : loc.latitude.toStringAsFixed(6));
    _lng = TextEditingController(
        text: loc == null ? '' : loc.longitude.toStringAsFixed(6));
    _address = TextEditingController(text: s?.addressText ?? '');
    _landmark = TextEditingController(text: s?.landmark ?? '');
    _radius = s?.geofenceRadiusM ?? 100;
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  /// Parses the entered pair through the SAME validator the wire uses, so a
  /// coordinate the backend would reject cannot leave this dialog.
  GeoPoint? _parseLocation() {
    return GeoPoint.tryParse(
      double.tryParse(_lat.text.trim()),
      double.tryParse(_lng.text.trim()),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _locationError = null;
    });

    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Stop name is required');
      return;
    }

    final location = _parseLocation();
    // A NEW stop must have a location. This is the gating rule for the entire
    // tracking feature, so it is enforced before the request, not after.
    if (!_isEdit && location == null) {
      setState(() => _locationError = _locationHint());
      return;
    }
    // On EDIT, a partially-typed coordinate is a mistake, not an intent to clear.
    final touchedLocation =
        _lat.text.trim().isNotEmpty || _lng.text.trim().isNotEmpty;
    if (_isEdit && touchedLocation && location == null) {
      setState(() => _locationError = _locationHint());
      return;
    }

    setState(() => _submitting = true);
    final mutations = ref.read(transportV2MutationsProvider.notifier);

    if (_isEdit) {
      await mutations.updateStop(
        stopId: widget.stop!.id,
        name: _name.text.trim(),
        location: location,
        geofenceRadiusM: _radius,
        addressText: _address.text.trim(),
        landmark: _landmark.text.trim(),
      );
    } else {
      await mutations.createStop(
        name: _name.text.trim(),
        location: location!,
        geofenceRadiusM: _radius,
        addressText: _address.text.trim(),
        landmark: _landmark.text.trim(),
      );
    }

    final state = ref.read(transportV2MutationsProvider);
    if (!mounted) return;
    setState(() => _submitting = false);

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
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.transportV2SuccessSnackbar,
        content: Text(state.successMessage ?? 'Saved'),
      ),
    );
  }

  /// One message covering every rejection reason, including (0,0) by name —
  /// an admin who typed zeros needs to know that is not a usable value.
  String _locationHint() =>
      'Enter a valid latitude (-90 to 90) and longitude (-180 to 180). '
      '0, 0 is not a real stop location.';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: QaTestKeys.transportV2StopFormDialog,
      title: Text(_isEdit ? 'Edit stop' : 'New stop'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: QaTestKeys.transportV2StopNameField,
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Stop name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),

            // BUS-086 seam. The pin-drop replaces these two fields with a nicer
            // input over the SAME validated value — not a new data path.
            Text(
              'Location',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              'A stop cannot be tracked without a location. Map pin-drop arrives '
              'with the map integration; enter the coordinate directly for now.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: QaTestKeys.transportV2StopLatField,
                    controller: _lat,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '17.44840',
                    ),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: TextField(
                    key: QaTestKeys.transportV2StopLngField,
                    controller: _lng,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '78.39080',
                    ),
                  ),
                ),
              ],
            ),
            if (_locationError != null) ...[
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                _locationError!,
                key: QaTestKeys.transportV2StopLocationError,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.error),
              ),
            ],
            const SizedBox(height: AksharaSpacing.s3),

            // The geofence radius drives automatic arrival detection (BUS-104),
            // so it is a real setting rather than a hidden constant.
            Text(
              'Geofence radius: $_radius m',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              key: QaTestKeys.transportV2StopRadiusSlider,
              value: _radius.toDouble(),
              min: 20,
              max: 500,
              divisions: 24,
              label: '$_radius m',
              onChanged: (v) => setState(() => _radius = v.round()),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            TextField(
              key: QaTestKeys.transportV2StopAddressField,
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.transportV2StopLandmarkField,
              controller: _landmark,
              decoration: const InputDecoration(
                labelText: 'Landmark (optional)',
                hintText: 'e.g. opposite the temple',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.transportV2StopFormSubmitButton,
          onPressed: _submitting ? null : _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
