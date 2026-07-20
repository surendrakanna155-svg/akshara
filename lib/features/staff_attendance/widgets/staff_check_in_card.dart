import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../manual_attendance_request_providers.dart';
import '../staff_attendance_models.dart';

/// Self-service staff check-in/out card (B4). Attendance is proven by being inside
/// the school geofence + a live camera face match (NO device biometric); the host
/// shows it only to staff who hold `Permission.markStaffAttendance`. Renders:
/// idle, verifying, recorded, and location-blocked / face-blocked / error.
///
/// Takes a deferred [onRecord] callback (rather than a pre-built controller) so
/// the host resolves the heavy reliability/biometric stack lazily — only on tap,
/// never at screen-build time.
///
/// PRA-P0-15: device capture currently always throws `DEVICE_ADAPTER_PENDING`
/// (no geolocator/camera build), so the card also surfaces the AUDITED
/// manual-attendance fallback — a "Request manual attendance" action for every
/// staff member, plus an "Approve manual requests" entry gated on the approver
/// permission ([canApproveManualAttendanceProvider]).
///
/// [onOpenEnrollment] (Slice 3), when provided, surfaces a settings-style entry
/// point to `FaceEnrollmentScreen` at all times, PLUS a prominent "Enrol my
/// face" call-to-action when the last outcome was specifically a
/// `FACE_NOT_ENROLLED` rejection ([StaffCheckOutcome.isNotEnrolled]).
///
/// [onManualRequest] (Slice 4), when provided, surfaces the design-sanctioned
/// fallback — "Request manual attendance" — whenever the chain could NOT
/// complete (location-blocked / face-blocked / failed). Never on a recorded
/// success. The host opens the submission flow with the attempted event.
///
/// W0.2b union: the widget is a ConsumerStatefulWidget (the state reads Riverpod
/// providers), carrying BOTH the PRA-P0-15 manual-fallback/approver-queue
/// callbacks and the DRP face-enrollment/manual-request callbacks.
class StaffCheckInCard extends ConsumerStatefulWidget {
  const StaffCheckInCard({
    super.key,
    required this.onRecord,
    this.onRequestManual,
    this.onOpenApproverQueue,
    this.onOpenEnrollment,
    this.onManualRequest,
  });

  final Future<StaffCheckOutcome> Function(StaffCheckEvent event) onRecord;
  final VoidCallback? onOpenEnrollment;
  final void Function(StaffCheckEvent? attempted)? onManualRequest;

  /// Overrides navigation to the manual-request screen (used in tests). When
  /// null the card pushes [RouteNames.hrStaffManualRequest].
  final VoidCallback? onRequestManual;

  /// Overrides navigation to the approver queue (used in tests). When null the
  /// card pushes [RouteNames.hrStaffManualRequestQueue].
  final VoidCallback? onOpenApproverQueue;

  @override
  ConsumerState<StaffCheckInCard> createState() => _StaffCheckInCardState();
}

class _StaffCheckInCardState extends ConsumerState<StaffCheckInCard> {
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

  void _openRequestManual() {
    final override = widget.onRequestManual;
    if (override != null) {
      override();
      return;
    }
    context.push(RouteNames.hrStaffManualRequest);
  }

  void _openApproverQueue() {
    final override = widget.onOpenApproverQueue;
    if (override != null) {
      override();
      return;
    }
    context.push(RouteNames.hrStaffManualRequestQueue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canApprove = ref.watch(canApproveManualAttendanceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('My attendance', style: theme.textTheme.titleMedium),
                ),
                // Slice 3 — always-available settings-style entry point to
                // manage the enrolled reference face (separate from the
                // FACE_NOT_ENROLLED call-to-action below).
                if (widget.onOpenEnrollment != null)
                  IconButton(
                    key: const Key('staff-attendance-manage-face-button'),
                    tooltip: 'Manage face enrollment',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: widget.onOpenEnrollment,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Be at school and face the camera to record your check-in or check-out.',
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
              // Slice 3 — the server rejected check-in specifically because
              // this staff member has no enrolled reference face yet. Offer
              // the fix inline rather than leaving them stuck on a banner.
              if (_last!.isNotEnrolled && widget.onOpenEnrollment != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const Key('staff-check-in-enrol-now-button'),
                    onPressed: widget.onOpenEnrollment,
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Enrol my face'),
                  ),
                ),
              ],
              // Slice 4 — the chain could not complete: offer the audited
              // manual-request fallback (design §3's ONLY sanctioned bypass).
              if (_last!.status != StaffCheckStatus.recorded &&
                  widget.onManualRequest != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('manual-request-cta'),
                    onPressed: () => widget.onManualRequest!(_lastEvent),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Request manual attendance'),
                  ),
                ),
              ],
            ],
            const Divider(height: 24),
            // PRA-P0-15 — audited fallback when device capture is unavailable.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('staff-request-manual-button'),
                onPressed: _openRequestManual,
                icon: const Icon(Icons.assignment_outlined, size: 18),
                label: const Text("Can't check in? Request manual attendance"),
              ),
            ),
            if (canApprove)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('staff-approve-manual-button'),
                  onPressed: _openApproverQueue,
                  icon: const Icon(Icons.rule, size: 18),
                  label: const Text('Approve manual requests'),
                ),
              ),
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
          // Check-in is online-only (audit R1) — a recorded outcome is always
          // a confirmed server write; there is no queued/pending state.
          '${event?.label ?? 'Attendance'} recorded.',
        ),
      StaffCheckStatus.locationBlocked => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.location_off,
          outcome.message ?? 'You must be inside the school geofence to record attendance.',
        ),
      StaffCheckStatus.faceBlocked => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.face_retouching_off,
          outcome.message ?? 'Face not verified. Face the camera in good light and try again.',
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
