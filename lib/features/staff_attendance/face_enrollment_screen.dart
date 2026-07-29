import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';
import '../../theme/theme_extensions.dart';
import 'attendance_capture_sources.dart';
import 'face_enrollment_datasource.dart';
import 'staff_attendance_models.dart';
import 'staff_attendance_providers.dart';

/// Self-service reference-face enrollment (Slice 3). Reuses the same
/// `FaceCaptureScreen` capture flow as check-in (pushed via the shared
/// [RouteNames.staffFaceCapture] route) and uploads the result through
/// [FaceEnrollmentDataSource]. Reachable both as a settings-style entry point
/// and — per the design brief — from the check-in card when the server has
/// just rejected a check-in with `FACE_NOT_ENROLLED`.
class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  FaceEnrollmentStatus? _status;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ref.read(faceEnrollmentDataSourceProvider).status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your enrollment status. Pull to refresh.';
        _loading = false;
      });
    }
  }

  Future<void> _enrol() async {
    if (_busy) return;
    // Audit R1 (P3): same gate the providers use — never push a camera screen
    // on a platform without the camera/ML plugin stack.
    if (!attendanceDeviceCaptureSupported) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // Pops with FaceCapture | AttendanceCaptureException (terminal, e.g.
      // FACE_MODEL_MISSING) | null (cancelled).
      final captured =
          await context.push<Object?>(RouteNames.staffFaceCapture);
      if (captured is AttendanceCaptureException) {
        if (!mounted) return;
        setState(() {
          _error = captured.message;
          _busy = false;
        });
        return;
      }
      if (captured is! FaceCapture) {
        if (!mounted) return;
        setState(() => _busy = false);
        return;
      }
      final face = captured;
      final result = await ref.read(faceEnrollmentDataSourceProvider).enroll(
            embedding: face.embedding,
            modelTag: face.modelTag,
          );
      if (!mounted) return;
      setState(() {
        _status = FaceEnrollmentStatus(
          enrolled: true,
          modelTag: result.modelTag,
          enrolledAt: result.enrolledAt,
        );
        _notice = 'Face enrolled. You can now check in with the camera.';
        _busy = false;
      });
    } on FaceEnrollmentRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _error = faceEnrollmentFriendlyMessage(e);
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not enrol your face. Try again.';
        _busy = false;
      });
    }
  }

  Future<void> _revoke() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(faceEnrollmentDataSourceProvider).revoke();
      if (!mounted) return;
      setState(() {
        _status = FaceEnrollmentStatus.notEnrolled;
        _notice = 'Your enrolled face was removed.';
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not remove your enrolled face. Try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = _status?.enrolled == true;
    return Scaffold(
      appBar: AppBar(title: const Text('My face enrollment')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(key: Key('face-enrollment-loading')),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Enrol a reference face so you can check in and out with the '
                    'camera. Only a privacy-preserving face embedding is stored — '
                    'never a photo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _EnrollmentStatusCard(status: _status),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        key: const Key('face-enrollment-error'),
                        style: context.aksharaText.bodyMedium
                            .copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _notice!,
                        key: const Key('face-enrollment-notice'),
                        style: context.aksharaText.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  // Audit R1 (P3): capture is gated on the same Android/iOS
                  // check the providers use — on other platforms the button is
                  // disabled with an explanation instead of a camera screen
                  // that can only error.
                  if (!attendanceDeviceCaptureSupported)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Face enrolment needs the mobile app — open NIKSHA OS on '
                        'your Android or iOS phone to enrol.',
                        key: const Key('face-enrollment-unsupported'),
                        style: context.aksharaText.bodySmall,
                      ),
                    ),
                  FilledButton.icon(
                    key: const Key('face-enrollment-enrol-button'),
                    onPressed: _busy || !attendanceDeviceCaptureSupported
                        ? null
                        : _enrol,
                    icon: const Icon(Icons.face_retouching_natural),
                    label: Text(enrolled ? 'Re-enrol my face' : 'Enrol my face'),
                  ),
                  if (enrolled) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('face-enrollment-revoke-button'),
                      onPressed: _busy ? null : _revoke,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove enrolled face'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EnrollmentStatusCard extends StatelessWidget {
  const _EnrollmentStatusCard({required this.status});

  final FaceEnrollmentStatus? status;

  @override
  Widget build(BuildContext context) {
    final enrolled = status?.enrolled == true;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('face-enrollment-status-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              enrolled ? Icons.verified_user : Icons.no_accounts,
              color: enrolled ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enrolled ? 'Face enrolled' : 'No face enrolled yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (enrolled)
                    Text(
                      'Model ${status?.modelTag ?? '—'}'
                      '${status?.enrolledAt != null ? ' · enrolled ${_formatDate(status!.enrolledAt!)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
