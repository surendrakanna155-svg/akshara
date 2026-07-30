import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../certificate_desk_datasource.dart';
import '../certificate_desk_models.dart';
import '../certificate_desk_providers.dart';

/// Certificate request detail. `blocked_dues` is shown HONESTLY — the
/// certificate was NOT issued because the student owes money — never as a
/// generic failure. Approve/reject live in the Principal Approval Center;
/// the only mutation here is Cancel (staff-only, approveCertificateRequest).
class CertificateRequestDetailDialog extends ConsumerStatefulWidget {
  const CertificateRequestDetailDialog({super.key, required this.request});

  final CertificateRequest request;

  @override
  ConsumerState<CertificateRequestDetailDialog> createState() =>
      _CertificateRequestDetailDialogState();
}

class _CertificateRequestDetailDialogState extends ConsumerState<CertificateRequestDetailDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(certificateDeskDataSourceProvider).cancel(widget.request.id);
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
        _error = 'Could not cancel the request. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final text = context.aksharaText;
    final canCancel =
        ref.watch(rbacServiceProvider).hasPermission(Permission.approveCertificateRequest);

    return AlertDialog(
      key: const Key('certificate-request-detail-dialog'),
      title: Text(certificateTypeLabel(request.certificateType)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Status', style: text.bodyMedium),
                const SizedBox(width: AksharaSpacing.s2),
                AksharaStatusChip(
                  label: certificateStatusLabel(request.status),
                  tone: _toneFor(request.status),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s3),
            _DetailRow(label: 'Student', value: request.studentId),
            _DetailRow(
              label: 'Purpose',
              value: request.purpose.isEmpty ? 'Not given' : request.purpose,
            ),
            _DetailRow(label: 'Requested by', value: request.requestedByRole),
            if (request.isBlockedDues && request.issueNote.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s3),
              AksharaWarningBanner(
                key: const Key('certificate-request-blocked-dues-note'),
                message: 'Not issued — outstanding dues: ${request.issueNote}',
                compactMessage: true,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                _error!,
                key: const Key('certificate-request-cancel-error'),
                style: text.bodySmall.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (request.isCancellable && canCancel)
          FilledButton.tonal(
            key: const Key('certificate-request-cancel-button'),
            onPressed: _busy ? null : _cancel,
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel request'),
          ),
      ],
    );
  }

  KpiAccent _toneFor(String status) => switch (status) {
        'issued' => KpiAccent.success,
        'approved' => KpiAccent.success,
        'pending' => KpiAccent.neutral,
        'rejected' => KpiAccent.error,
        'blocked_dues' => KpiAccent.error,
        'cancelled' => KpiAccent.neutral,
        _ => KpiAccent.neutral,
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: text.bodySmall),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
