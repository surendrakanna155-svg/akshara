import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/akshara_status_chip.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'certificate_desk_models.dart';
import 'certificate_desk_providers.dart';
import 'widgets/certificate_request_detail_dialog.dart';
import 'widgets/certificate_request_raise_dialog.dart';

/// Certificate Request Desk — the staff queue (RouteNames.certificateRequests).
/// Approve/reject decisions happen in the existing Principal Approval Center
/// (F2 `certificateRequest` type) — this screen only raises requests, browses
/// the queue with a status filter, and cancels a pending one.
///
/// Permission gating is a plain `hasPermission` check (NOT [AksharaManageAction]
/// / [AksharaApproveAction]): those wrap [ManagePermissionGuard] /
/// [ApprovePermissionGuard], which only recognize permissions named
/// `manage*` / `approve*` — `requestStudentCertificate` matches neither, so
/// [AksharaManageAction] would silently deny it outright.
class CertificateRequestsScreen extends ConsumerWidget {
  const CertificateRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(certificateRequestsProvider);
    final filter = ref.watch(certificateRequestStatusFilterProvider);
    final viewState = resolveErpAsync(async, isDataEmpty: (items) => items.isEmpty);
    final canRaise =
        ref.watch(rbacServiceProvider).hasPermission(Permission.requestStudentCertificate);

    return Scaffold(
      key: const Key('certificate-requests-screen'),
      appBar: AppBar(title: const Text('Certificate Requests')),
      floatingActionButton: canRaise
          ? FloatingActionButton.extended(
              key: const Key('certificate-request-raise-button'),
              onPressed: () => _openRaiseDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Raise request'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.s4,
              AksharaSpacing.s4,
              AksharaSpacing.s4,
              0,
            ),
            child: _StatusFilterBar(
              selected: filter,
              statuses: certificateRequestStatuses,
              labelBuilder: certificateStatusLabel,
              onSelected: (status) =>
                  ref.read(certificateRequestStatusFilterProvider.notifier).state = status,
            ),
          ),
          Expanded(
            child: ErpAsyncBody<List<CertificateRequest>>(
              state: viewState,
              loadingLabel: 'Loading certificate requests',
              emptyMessage: 'No certificate requests yet.',
              emptyIcon: Icons.badge_outlined,
              onRetry: () => retryErpFuture(ref, certificateRequestsProvider),
              builder: (items) => ListView.separated(
                key: const Key('certificate-requests-list'),
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AksharaSpacing.s2),
                itemBuilder: (context, index) {
                  final request = items[index];
                  return _CertificateRequestTile(
                    request: request,
                    onTap: () => _openDetailDialog(context, ref, request),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRaiseDialog(BuildContext context, WidgetRef ref) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => const CertificateRequestRaiseDialog(),
    );
    if (submitted == true) {
      ref.invalidate(certificateRequestsProvider);
    }
  }

  Future<void> _openDetailDialog(
    BuildContext context,
    WidgetRef ref,
    CertificateRequest request,
  ) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => CertificateRequestDetailDialog(request: request),
    );
    if (changed == true) {
      ref.invalidate(certificateRequestsProvider);
    }
  }
}

class _CertificateRequestTile extends StatelessWidget {
  const _CertificateRequestTile({required this.request, required this.onTap});

  final CertificateRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      elevation: 0,
      child: ListTile(
        key: Key('certificate-request-tile-${request.id}'),
        onTap: onTap,
        title: Text('${certificateTypeLabel(request.certificateType)} — ${request.studentId}'),
        subtitle: Text(
          request.purpose.isEmpty ? 'No purpose given' : request.purpose,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
        trailing: AksharaStatusChip(
          label: certificateStatusLabel(request.status),
          tone: _toneFor(request.status),
        ),
      ),
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

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selected,
    required this.statuses,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String? selected;
  final List<String> statuses;
  final String Function(String) labelBuilder;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AksharaSpacing.s2),
            child: ChoiceChip(
              key: const Key('certificate-request-status-filter-all'),
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.only(right: AksharaSpacing.s2),
              child: ChoiceChip(
                key: Key('certificate-request-status-filter-$status'),
                label: Text(labelBuilder(status)),
                selected: selected == status,
                onSelected: (_) => onSelected(status),
              ),
            ),
        ],
      ),
    );
  }
}
