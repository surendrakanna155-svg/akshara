import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';
import '../manual_request_datasource.dart';
import '../staff_attendance_models.dart';

/// P1-PROD-22 slice 4 — the staff-side Manual Attendance Request submission
/// dialog: the audited fallback when the geofence + live-face chain cannot
/// complete. On open it checks the caller's own requests; if one is already
/// pending it says so instead of allowing a duplicate. Otherwise: event type
/// (prefilled from the attempted event) + reason (min 3 chars, mirroring the
/// server's REASON_REQUIRED) → POST → "pending approval" confirmation.
class ManualRequestDialog extends StatefulWidget {
  const ManualRequestDialog({
    super.key,
    required this.datasource,
    this.attempted,
  });

  final ManualAttendanceRequestDataSource datasource;
  final StaffCheckEvent? attempted;

  @override
  State<ManualRequestDialog> createState() => _ManualRequestDialogState();
}

enum _Phase { checking, form, submitting, submitted, alreadyPending }

class _ManualRequestDialogState extends State<ManualRequestDialog> {
  final _reasonController = TextEditingController();
  late StaffCheckEvent _event = widget.attempted ?? StaffCheckEvent.checkIn;
  _Phase _phase = _Phase.checking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    try {
      final mine = await widget.datasource.myRequests();
      if (!mounted) return;
      setState(() {
        _phase = mine.any((r) => r.isPending) ? _Phase.alreadyPending : _Phase.form;
      });
    } catch (_) {
      // The duplicate check is best-effort — the server keeps its own record;
      // never block the fallback on a failed read.
      if (!mounted) return;
      setState(() => _phase = _Phase.form);
    }
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'Give a short reason (at least 3 characters).');
      return;
    }
    setState(() {
      _phase = _Phase.submitting;
      _error = null;
    });
    try {
      await widget.datasource.create(event: _event, reason: reason);
      if (!mounted) return;
      setState(() => _phase = _Phase.submitted);
    } on StaffAttendanceRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = 'Could not send the request. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return AlertDialog(
      key: const Key('manual-request-dialog'),
      title: const Text('Manual attendance request'),
      content: switch (_phase) {
        _Phase.checking => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        _Phase.alreadyPending => Text(
            'A request is already pending approval — your approver will '
            'action it. You can raise the next one after it is decided.',
            key: const Key('manual-request-already-pending'),
            style: text.bodyMedium,
          ),
        _Phase.submitted => Text(
            'Request sent — pending approval. Your attendance will be '
            'recorded when an approver accepts it.',
            key: const Key('manual-request-submitted'),
            style: text.bodyMedium,
          ),
        _Phase.form || _Phase.submitting => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use this only when the location or camera check cannot '
                'complete. An approver reviews every request.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              SegmentedButton<StaffCheckEvent>(
                key: const Key('manual-request-event-type'),
                segments: const [
                  ButtonSegment(
                    value: StaffCheckEvent.checkIn,
                    label: Text('Check in'),
                  ),
                  ButtonSegment(
                    value: StaffCheckEvent.checkOut,
                    label: Text('Check out'),
                  ),
                ],
                selected: {_event},
                onSelectionChanged: _phase == _Phase.submitting
                    ? null
                    : (selection) => setState(() => _event = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('manual-request-reason'),
                controller: _reasonController,
                enabled: _phase != _Phase.submitting,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. camera not working, GPS unavailable',
                  errorText: _error,
                ),
              ),
            ],
          ),
      },
      actions: switch (_phase) {
        _Phase.submitted || _Phase.alreadyPending => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        _Phase.checking => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        _Phase.form || _Phase.submitting => [
            TextButton(
              onPressed: _phase == _Phase.submitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('manual-request-submit'),
              onPressed: _phase == _Phase.submitting ? null : _submit,
              child: _phase == _Phase.submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send request'),
            ),
          ],
      },
    );
  }
}
