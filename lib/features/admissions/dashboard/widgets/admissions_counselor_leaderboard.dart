import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_section_empty.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../../admin/admin_layout.dart';

/// Counselor leaderboard strip for AD-01.
class AdmissionsCounselorLeaderboard extends StatelessWidget {
  const AdmissionsCounselorLeaderboard({
    super.key,
    required this.entries,
  });

  final List<CounselorLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Same defect as the pipeline: an empty list inside a fixed 120px box is
    // 120px of blank space under a header on day one.
    if (entries.isEmpty) {
      return const AksharaSectionEmpty(
        message: 'No counselor activity yet. Rankings appear once leads are '
            'assigned.',
        icon: Icons.leaderboard_outlined,
      );
    }

    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final entry in entries) ...[
            _LeaderboardTile(entry: entry),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Counselor leaderboard, ${entries.length} counselors',
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s3),
          itemBuilder: (context, index) =>
              _LeaderboardTile(entry: entries[index]),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});

  final CounselorLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label:
          '${entry.counselor}, ${entry.conversions} conversions, ${entry.conversionRate} percent rate',
      child: Material(
        color: colors.surface,
        borderRadius: AksharaRadius.card,
        child: Container(
          width: AdminLayout.isMobile(context) ? double.infinity : 260,
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: AksharaRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.counselor,
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                '${entry.leadsHandled} leads · ${entry.conversions} joined',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              Text(
                '${entry.conversionRate.toStringAsFixed(1)}% conversion',
                style: text.labelLarge.copyWith(color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
