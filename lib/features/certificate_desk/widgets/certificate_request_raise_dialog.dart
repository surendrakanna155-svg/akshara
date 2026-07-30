import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/forms/akshara_searchable_dropdown.dart';
import '../../../theme/theme_extensions.dart';
import '../certificate_desk_datasource.dart';
import '../certificate_desk_models.dart';
import '../certificate_desk_providers.dart';

/// Raise a certificate request (requestStudentCertificate). The FAB that
/// opens this is already gated by [AksharaManageAction] in the screen, so
/// this dialog assumes the caller may raise.
class CertificateRequestRaiseDialog extends ConsumerStatefulWidget {
  const CertificateRequestRaiseDialog({super.key});

  @override
  ConsumerState<CertificateRequestRaiseDialog> createState() =>
      _CertificateRequestRaiseDialogState();
}

class _CertificateRequestRaiseDialogState extends ConsumerState<CertificateRequestRaiseDialog> {
  final _studentId = TextEditingController();
  final _purpose = TextEditingController();
  String _certificateType = certificateRequestTypes.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _studentId.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final studentId = _studentId.text.trim();
    if (studentId.isEmpty) {
      setState(() => _error = 'Enter the student ID, admission number, or student code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(certificateDeskDataSourceProvider).raise(
            studentId: studentId,
            certificateType: _certificateType,
            purpose: _purpose.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CertificateRequestRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send the request. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return AlertDialog(
      key: const Key('certificate-request-raise-dialog'),
      title: const Text('Raise certificate request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('certificate-request-student-id-field'),
              controller: _studentId,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Student ID, admission no., or code',
              ),
            ),
            const SizedBox(height: 12),
            AksharaSearchableDropdown(
              label: 'Certificate type',
              value: certificateTypeLabel(_certificateType),
              options: [for (final t in certificateRequestTypes) certificateTypeLabel(t)],
              enabled: !_busy,
              onChanged: (label) {
                final match = certificateRequestTypes.firstWhere(
                  (t) => certificateTypeLabel(t) == label,
                  orElse: () => certificateRequestTypes.first,
                );
                setState(() => _certificateType = match);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate-request-purpose-field'),
              controller: _purpose,
              enabled: !_busy,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Purpose (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                key: const Key('certificate-request-raise-error'),
                style: text.bodySmall.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('certificate-request-submit-button'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Raise request'),
        ),
      ],
    );
  }
}
