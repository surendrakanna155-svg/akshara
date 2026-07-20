import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'manual_attendance_request_models.dart';
import 'manual_attendance_request_providers.dart';
import 'staff_attendance_models.dart';

/// PRA-P0-15 — the staff-facing side of the audited manual-attendance fallback.
/// When device capture (GPS + live face) is unavailable, a staff member raises
/// an audited request here; an approver decides it and, on approve, the server
/// mints a real check-in. Posts to POST /staff-attendance/manual-request.
class ManualAttendanceRequestScreen extends ConsumerStatefulWidget {
  const ManualAttendanceRequestScreen({super.key});

  @override
  ConsumerState<ManualAttendanceRequestScreen> createState() =>
      _ManualAttendanceRequestScreenState();
}

class _ManualAttendanceRequestScreenState
    extends ConsumerState<ManualAttendanceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  StaffCheckEvent _event = StaffCheckEvent.checkIn;
  bool _busy = false;
  ManualRequestSubmitResult? _result;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _result = null;
      _errorMessage = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(manualAttendanceRequestDataSourceProvider).submit(
                event: _event,
                reason: _reasonController.text.trim(),
              );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
      _reasonController.clear();
    } on ManualAttendanceRequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'Could not submit the request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Request manual attendance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Use this when the camera or location check is unavailable on '
                'your device. Your request is logged and sent to an approver; '
                'attendance is only recorded once they approve it.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text('Which event?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<StaffCheckEvent>(
                key: const Key('manual-request-event-selector'),
                segments: const [
                  ButtonSegment(
                    value: StaffCheckEvent.checkIn,
                    label: Text('Check in'),
                    icon: Icon(Icons.login),
                  ),
                  ButtonSegment(
                    value: StaffCheckEvent.checkOut,
                    label: Text('Check out'),
                    icon: Icon(Icons.logout),
                  ),
                ],
                selected: {_event},
                onSelectionChanged: _busy
                    ? null
                    : (selection) => setState(() => _event = selection.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('manual-request-reason-field'),
                controller: _reasonController,
                enabled: !_busy,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. Camera not working on my phone today',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final reason = (value ?? '').trim();
                  if (reason.length < 3) {
                    return 'Enter a reason (at least 3 characters).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('manual-request-submit'),
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_busy ? 'Submitting…' : 'Submit request'),
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                _ResultBanner(
                  key: const Key('manual-request-success'),
                  icon: Icons.check_circle,
                  background: theme.colorScheme.secondaryContainer,
                  foreground: theme.colorScheme.onSecondaryContainer,
                  text:
                      'Request submitted (${_result!.eventType.label.toLowerCase()}). '
                      'It is now ${_result!.status.label.toLowerCase()} an approver\'s '
                      'decision.',
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _ResultBanner(
                  key: const Key('manual-request-error'),
                  icon: Icons.error_outline,
                  background: theme.colorScheme.errorContainer,
                  foreground: theme.colorScheme.onErrorContainer,
                  text: _errorMessage!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.text,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: foreground))),
        ],
      ),
    );
  }
}
