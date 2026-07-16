import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../shared/async/erp_async_state.dart';
import '../../core/security/rbac_service.dart';
import '../../shared/widgets/akshara_status_chip.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'gate_pass_models.dart';
import 'gate_pass_providers.dart';
import 'widgets/gate_pass_detail_dialog.dart';
import 'widgets/gate_pass_raise_dialog.dart';
import 'widgets/gate_pass_verify_dialog.dart';

/// Gate Pass / early pickup — the staff queue (RouteNames.gatePasses).
/// Approve/reject decisions happen in the existing Principal Approval Center
/// (F2 `gatePass` type). This screen raises passes, browses the queue with a
/// status filter, and is the verify surface where gate staff enter the OTP a
/// parent presents.
///
/// ⚠ Permission gating here is a plain `hasPermission` check, NOT
/// [AksharaManageAction]. That widget wraps `ManagePermissionGuard`, which gates
/// on `hasManagePermission` == `isManagePermission(p) && hasPermission(p)`, and
/// `isManagePermission` is literally `p.name.startsWith('manage')`
/// (mutation_permission_validator.dart:19). `requestGatePass`/`verifyGatePass`
/// start with neither `manage` nor `approve`, so the guard would fail CLOSED for
/// EVERY caller — the affordance would never render for anyone, including a
/// holder. The naming convention is load-bearing. Same conclusion the
/// certificate desk reached; see certificate_requests_screen.dart.
class GatePassesScreen extends ConsumerWidget {
  const GatePassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gatePassesProvider);
    final filter = ref.watch(gatePassStatusFilterProvider);
    final viewState = resolveErpAsync(async, isDataEmpty: (items) => items.isEmpty);
    final rbac = ref.watch(rbacServiceProvider);
    final canRaise = rbac.hasPermission(Permission.requestGatePass);
    final canVerify = rbac.hasPermission(Permission.verifyGatePass);

    return Scaffold(
      key: const Key('gate-passes-screen'),
      appBar: AppBar(title: const Text('Gate Passes')),
      floatingActionButton: canRaise
          ? FloatingActionButton.extended(
              key: const Key('gate-pass-raise-button'),
              onPressed: () => _openRaiseDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Raise pass'),
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
              statuses: gatePassStatuses,
              labelBuilder: gatePassStatusLabel,
              onSelected: (status) =>
                  ref.read(gatePassStatusFilterProvider.notifier).state = status,
            ),
          ),
          Expanded(
            child: ErpAsyncBody<List<GatePass>>(
              state: viewState,
              loadingLabel: 'Loading gate passes',
              emptyMessage: 'No gate passes yet.',
              emptyIcon: Icons.badge_outlined,
              onRetry: () => retryErpFuture(ref, gatePassesProvider),
              builder: (items) => ListView.separated(
                key: const Key('gate-passes-list'),
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AksharaSpacing.s2),
                itemBuilder: (context, index) {
                  final pass = items[index];
                  return _GatePassTile(
                    gatePass: pass,
                    canVerify: canVerify,
                    onTap: () => _openDetailDialog(context, ref, pass),
                    onVerify: () => _openVerifyDialog(context, ref, pass),
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
      builder: (_) => const GatePassRaiseDialog(),
    );
    if (submitted == true) {
      ref.invalidate(gatePassesProvider);
    }
  }

  Future<void> _openDetailDialog(BuildContext context, WidgetRef ref, GatePass pass) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => GatePassDetailDialog(gatePass: pass),
    );
    if (changed == true) {
      ref.invalidate(gatePassesProvider);
    }
  }

  Future<void> _openVerifyDialog(BuildContext context, WidgetRef ref, GatePass pass) async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (_) => GatePassVerifyDialog(gatePass: pass),
    );
    if (verified == true) {
      ref.invalidate(gatePassesProvider);
    }
  }
}

class _GatePassTile extends StatelessWidget {
  const _GatePassTile({
    required this.gatePass,
    required this.canVerify,
    required this.onTap,
    required this.onVerify,
  });

  final GatePass gatePass;
  final bool canVerify;
  final VoidCallback onTap;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      elevation: 0,
      child: ListTile(
        key: Key('gate-pass-tile-${gatePass.id}'),
        onTap: onTap,
        title: Text('${gatePassTypeLabel(gatePass.passType)} — ${gatePass.studentId}'),
        subtitle: Text(
          '${gatePass.pickupPersonName} · ${gatePass.scheduledAt}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AksharaStatusChip(
              label: gatePassStatusLabel(gatePass.status),
              tone: _toneFor(gatePass.status),
            ),
            // `verifyGatePass` is neither manage* nor approve*, so it must be a
            // plain hasPermission check — see the class doc.
            if (gatePass.isVerifiable && canVerify)
              IconButton(
                key: Key('gate-pass-verify-action-${gatePass.id}'),
                onPressed: onVerify,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                tooltip: 'Verify',
              ),
          ],
        ),
      ),
    );
  }

  KpiAccent _toneFor(String status) => switch (status) {
        'used' => KpiAccent.success,
        'approved' => KpiAccent.success,
        'pending' => KpiAccent.neutral,
        'rejected' => KpiAccent.error,
        'expired' => KpiAccent.error,
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
              key: const Key('gate-pass-status-filter-all'),
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.only(right: AksharaSpacing.s2),
              child: ChoiceChip(
                key: Key('gate-pass-status-filter-$status'),
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
