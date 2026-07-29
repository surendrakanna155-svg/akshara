import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/theme_extensions.dart';
import '../attendance_capture_sources.dart';
import '../geofence_datasource.dart';

/// School-attendance geofence configuration — the missing half of
/// docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §4 ("configurable school geofence
/// radius (per school; default 100 m, e.g. 50 / 100 / 150 / 200 / 300 m)").
///
/// Until a geofence exists, `POST /staff-attendance/check` rejects EVERY
/// check-in with `STAFF_ATTENDANCE_GEOFENCE_NOT_CONFIGURED`, so this is the
/// setup step that turns staff attendance on for a school.
///
/// [locationSource] is optional: when supplied (and the platform has the real
/// geolocator adapter) the admin can drop the centre on their current position
/// — "stand at the school gate and tap". When it is absent or fails, manual
/// lat/lng entry is always available, so this dialog never dead-ends.
///
/// The SERVER re-enforces `manageSchoolGeofence` on the write; the host only
/// decides whether to offer the affordance.
class GeofenceSettingsDialog extends StatefulWidget {
  const GeofenceSettingsDialog({
    super.key,
    required this.datasource,
    this.locationSource,
  });

  final SchoolGeofenceDataSource datasource;
  final AttendanceLocationSource? locationSource;

  @override
  State<GeofenceSettingsDialog> createState() => _GeofenceSettingsDialogState();
}

enum _Phase { loading, form, saving, saved }

class _GeofenceSettingsDialogState extends State<GeofenceSettingsDialog> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _accuracyController = TextEditingController(
    text: '${SchoolGeofence.defaultMaxAccuracyM}',
  );

  _Phase _phase = _Phase.loading;
  int _radiusM = SchoolGeofence.defaultRadiusM;
  int _maxLocationAgeS = SchoolGeofence.defaultMaxLocationAgeS;
  bool _existing = false;
  bool _locating = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _accuracyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final current = await widget.datasource.fetch();
      if (!mounted) return;
      setState(() {
        if (current != null) {
          _existing = true;
          _latController.text = '${current.centerLatitude}';
          _lngController.text = '${current.centerLongitude}';
          _accuracyController.text = '${current.maxAccuracyM}';
          _radiusM = SchoolGeofence.radiusChoices.contains(current.radiusM)
              ? current.radiusM
              : _nearestRadiusChoice(current.radiusM);
          _maxLocationAgeS = current.maxLocationAgeS;
        }
        _phase = _Phase.form;
      });
    } catch (_) {
      // A failed read must never block the write path — the admin can still
      // set a geofence. Say so honestly rather than showing a blank form that
      // silently discards an existing configuration without warning.
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = 'Could not read the current geofence. Saving will replace '
            'whatever is stored.';
      });
    }
  }

  static int _nearestRadiusChoice(int radiusM) {
    var best = SchoolGeofence.radiusChoices.first;
    for (final choice in SchoolGeofence.radiusChoices) {
      if ((choice - radiusM).abs() < (best - radiusM).abs()) best = choice;
    }
    return best;
  }

  Future<void> _useCurrentLocation() async {
    final source = widget.locationSource;
    if (source == null || _locating) return;
    setState(() {
      _locating = true;
      _error = null;
      _notice = null;
    });
    try {
      final fix = await source.acquire();
      if (!mounted) return;
      if (fix.isMock) {
        // A mock fix would anchor the whole school's geofence to a spoofed
        // point — the one place a fake GPS would do permanent damage.
        setState(() {
          _locating = false;
          _error = 'Mock / fake GPS detected. Turn off mock locations before '
              'setting the school centre.';
        });
        return;
      }
      setState(() {
        _locating = false;
        _latController.text = '${fix.latitude}';
        _lngController.text = '${fix.longitude}';
        _notice = 'Centre set to your current position '
            '(±${fix.accuracyM.round()} m).';
      });
    } on AttendanceCaptureException catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = 'Could not get your location. Enter the coordinates manually.';
      });
    }
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      setState(() => _error = 'Enter the school centre latitude and longitude.');
      return;
    }
    final accuracy = int.tryParse(_accuracyController.text.trim()) ??
        SchoolGeofence.defaultMaxAccuracyM;

    final candidate = SchoolGeofence(
      centerLatitude: lat,
      centerLongitude: lng,
      radiusM: _radiusM,
      maxAccuracyM: accuracy,
      maxLocationAgeS: _maxLocationAgeS,
    );
    final invalid = candidate.validationError();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _phase = _Phase.saving;
      _error = null;
      _notice = null;
    });
    try {
      await widget.datasource.save(candidate);
      if (!mounted) return;
      setState(() => _phase = _Phase.saved);
    } on SchoolGeofenceRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = 'Could not save the geofence. Check your connection and try '
            'again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final busy = _phase == _Phase.saving;
    return AlertDialog(
      key: const Key('geofence-settings-dialog'),
      title: const Text('School attendance geofence'),
      content: switch (_phase) {
        _Phase.loading => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        _Phase.saved => Text(
            'Geofence saved. Staff inside this area can now check in with a '
            'live face capture.',
            key: const Key('geofence-settings-saved'),
            style: text.bodyMedium,
          ),
        _Phase.form || _Phase.saving => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _existing
                      ? 'Staff can only record attendance inside this area.'
                      : 'No geofence is set yet — staff check-in stays blocked '
                          'until you set one.',
                  key: Key(
                    _existing
                        ? 'geofence-settings-existing'
                        : 'geofence-settings-unconfigured',
                  ),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                if (widget.locationSource != null)
                  OutlinedButton.icon(
                    key: const Key('geofence-use-current-location'),
                    onPressed: busy || _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Use my current location'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('geofence-latitude'),
                  controller: _latController,
                  enabled: !busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true, decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Centre latitude'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('geofence-longitude'),
                  controller: _lngController,
                  enabled: !busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true, decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Centre longitude'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const Key('geofence-radius'),
                  initialValue: _radiusM,
                  decoration: const InputDecoration(labelText: 'Radius'),
                  items: [
                    for (final choice in SchoolGeofence.radiusChoices)
                      DropdownMenuItem(value: choice, child: Text('$choice m')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(
                            () => _radiusM = value ?? SchoolGeofence.defaultRadiusM,
                          ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('geofence-accuracy'),
                  controller: _accuracyController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Reject fixes worse than (m)',
                    helperText: 'Between 5 m and 200 m',
                  ),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _notice!,
                    key: const Key('geofence-settings-notice'),
                    style: text.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    key: const Key('geofence-settings-error'),
                    style: text.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
      },
      actions: switch (_phase) {
        _Phase.saved => [
            TextButton(
              key: const Key('geofence-settings-done'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        _Phase.loading => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        _Phase.form || _Phase.saving => [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('geofence-settings-save'),
              onPressed: busy ? null : _save,
              child: busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save geofence'),
            ),
          ],
      },
    );
  }
}
