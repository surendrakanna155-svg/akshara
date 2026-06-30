import 'package:flutter/material.dart';

import '../staff_attendance_models.dart';

/// Self-service staff check-in/out card (O5). Biometric-gated; the host shows it
/// only to staff who hold `Permission.markStaffAttendance`. Renders four states:
/// idle, verifying, recorded, and biometric-blocked / error.
///
/// Takes a deferred [onRecord] callback (rather than a pre-built controller) so
/// the host resolves the heavy reliability/biometric stack lazily — only on tap,
/// never at screen-build time.
class StaffCheckInCard extends StatefulWidget {
  const StaffCheckInCard({super.key, required this.onRecord});

  final Future<StaffCheckOutcome> Function(StaffCheckEvent event) onRecord;

  @override
  State<StaffCheckInCard> createState() => _StaffCheckInCardState();
}

class _StaffCheckInCardState extends State<StaffCheckInCard> {
  bool _busy = false;
  StaffCheckOutcome? _last;
  StaffCheckEvent? _lastEvent;

  Future<void> _record(StaffCheckEvent event) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastEvent = event;
      _last = null;
    });
    final outcome = await widget.onRecord(event);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fingerprint),
                const SizedBox(width: 8),
                Text('My attendance', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Confirm with Face ID / fingerprint to record your check-in or check-out.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Row(
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Verifying…'),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('staff-check-in-button'),
                      onPressed: () => _record(StaffCheckEvent.checkIn),
                      icon: const Icon(Icons.login),
                      label: const Text('Check in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('staff-check-out-button'),
                      onPressed: () => _record(StaffCheckEvent.checkOut),
                      icon: const Icon(Icons.logout),
                      label: const Text('Check out'),
                    ),
                  ),
                ],
              ),
            if (_last != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(outcome: _last!, event: _lastEvent),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.outcome, this.event});

  final StaffCheckOutcome outcome;
  final StaffCheckEvent? event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon, String text) = switch (outcome.status) {
      StaffCheckStatus.recorded => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.check_circle,
          outcome.record?.pendingSync == true
              ? '${event?.label ?? 'Attendance'} queued — will sync when online.'
              : '${event?.label ?? 'Attendance'} recorded.',
        ),
      StaffCheckStatus.biometricRequired => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.fingerprint,
          outcome.message ?? 'Biometric verification is required to record attendance.',
        ),
      StaffCheckStatus.failed => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
          'Couldn\'t record attendance. ${outcome.message ?? ''}'.trim(),
        ),
    };
    return Container(
      key: const Key('staff-check-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: fg))),
        ],
      ),
    );
  }
}
