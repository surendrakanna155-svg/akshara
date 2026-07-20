import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'support_providers.dart';

/// ASIP Phase 1 screen (a) — "Report an issue to Akshara Support".
///
/// The reporter provides only a short summary, an optional description and an
/// optional screenshot. Everything technical (app version, device, OS, screen,
/// session, correlation IDs, breadcrumbs, recent API calls) is auto-collected by
/// [IncidentContextService] on submit — we never ask the user for it.
///
/// TODO(asip-phase2): screen-recording capture. Phase 1 ships screenshot only
/// because on-device screen recording is platform-hard (Android MediaProjection
/// consent + foreground service; iOS ReplayKit broadcast extension) and no
/// robust cross-platform Flutter plugin exists. The wire contract already
/// supports `kind: 'screen_recording'`; the UI shows a disabled affordance until
/// the capture pipeline lands.
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  ReportAttachment? _screenshot;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _titleController.text.trim().isNotEmpty;

  Future<void> _pickScreenshot(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _screenshot = ReportAttachment(
          bytes: bytes,
          fileName: file.name,
          contentType: file.mimeType ?? _contentTypeFor(file.name),
        );
      });
    } on Object {
      if (!mounted) return;
      _showSnack('Could not add that image. Please try another.');
    }
  }

  void _chooseScreenshotSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickScreenshot(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickScreenshot(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final incident = await ref.read(supportActionsProvider).submitReport(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            screenshot: _screenshot,
          );
      if (!mounted) return;
      _showSnack('Reported ${incident.publicRef}. Support will investigate.');
      context.pushReplacement(
        RouteNames.supportIncidentDetail(incident.id),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack('Could not send your report. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Scaffold(
      key: QaTestKeys.supportReportScreen,
      backgroundColor: colors.surfaceContainerLow,
      appBar: const AksharaAppBar(
        titleText: 'Report an issue',
        subtitle: 'Tell us what went wrong',
        trailingPadding: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s4,
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s10,
            ),
            children: [
              Text(
                'Describe the problem in your own words. You do not need to '
                'include any technical details.',
                style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s5),
              TextField(
                key: QaTestKeys.supportReportTitleField,
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText: 'e.g. Fee receipt opens blank',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextField(
                key: QaTestKeys.supportReportDescriptionField,
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Add more detail (optional)',
                  hintText:
                      'What were you trying to do? What did you expect to happen?',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              _ScreenshotField(
                screenshot: _screenshot,
                onAdd: _chooseScreenshotSource,
                onRemove: () => setState(() => _screenshot = null),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              const _ScreenRecordingAffordance(),
              const SizedBox(height: AksharaSpacing.s4),
              _AutoDiagnosticsNote(color: colors.surfaceContainerHigh),
              const SizedBox(height: AksharaSpacing.s6),
              FilledButton.icon(
                key: QaTestKeys.supportReportSubmitButton,
                onPressed: _canSubmit ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Sending…' : 'Send to Akshara Support'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _ScreenshotField extends StatelessWidget {
  const _ScreenshotField({
    required this.screenshot,
    required this.onAdd,
    required this.onRemove,
  });

  final ReportAttachment? screenshot;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    if (screenshot == null) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add screenshot'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AksharaSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AksharaSpacing.s2),
            child: Image.memory(
              screenshot!.bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image_outlined,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Screenshot attached',
                  style: text.labelLarge.copyWith(color: colors.onSurface),
                ),
                Text(
                  screenshot!.fileName,
                  style:
                      text.labelSmall.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove screenshot',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Disabled Phase-1 affordance for screen recording (see the class-level TODO).
class _ScreenRecordingAffordance extends StatelessWidget {
  const _ScreenRecordingAffordance();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Opacity(
      opacity: 0.6,
      child: Tooltip(
        message: 'Screen recording is coming in a future update.',
        child: Row(
          children: [
            Icon(Icons.videocam_off_outlined, color: colors.onSurfaceVariant),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Text(
                'Add screen recording (coming soon)',
                style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoDiagnosticsNote extends StatelessWidget {
  const _AutoDiagnosticsNote({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Container(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: colors.primary),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Text(
              'We will automatically attach the technical details we need — your '
              'app version, device, the screen you were on and your recent '
              'activity. You never have to enter device info, logs or IDs.',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
