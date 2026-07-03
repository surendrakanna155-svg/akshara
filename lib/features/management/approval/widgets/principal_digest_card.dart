import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/permissions.dart';
import '../../../../core/security/rbac_service.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../approval_center_provider.dart';

/// PRI-4 — the weekly principal digest: an in-app read card summarising the top
/// priorities / risks / pending items from the already-loaded approval queue +
/// operations-hub aggregates. No cron (XCT-2 / deployment owns the scheduled
/// send) — this is purely a read surface. RBAC-gated on viewManagement.
class PrincipalDigestCard extends ConsumerWidget {
  const PrincipalDigestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.viewManagement)) {
      return const SizedBox.shrink();
    }

    final digest = ref.watch(principalDigestProvider);
    if (digest.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s4),
      child: Card(
        key: QaTestKeys.principalDigestCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize_outlined, color: colors.primary),
                  const SizedBox(width: AksharaSpacing.s2),
                  Text('This week at a glance', style: text.titleSmall),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s2,
                children: [
                  for (final item in digest.items)
                    _DigestChip(
                      label: item.label,
                      value: item.value,
                      tone: _toneFor(item.tone),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  KpiAccent _toneFor(String tone) => switch (tone) {
        'error' => KpiAccent.error,
        'warning' => KpiAccent.warning,
        'success' => KpiAccent.success,
        _ => KpiAccent.neutral,
      };
}

class _DigestChip extends StatelessWidget {
  const _DigestChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final KpiAccent tone;

  @override
  Widget build(BuildContext context) {
    return AksharaStatusChip(label: '$label: $value', tone: tone);
  }
}
