import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/approvals/approval_category.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../approval_center_provider.dart';

/// Category filter chips for the Principal Approval Center.
class ApprovalTypeFilter extends ConsumerWidget {
  const ApprovalTypeFilter({super.key});

  static const categories = ApprovalCategory.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(approvalCenterCategoryFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: AksharaSpacing.s2),
              child: FilterChip(
                key: _chipKey(category),
                label: Text(category.label),
                selected: selected == category,
                onSelected: (_) {
                  ref.read(approvalCenterCategoryFilterProvider.notifier).state =
                      category;
                  ref.read(approvalCenterSelectedIdProvider.notifier).state =
                      null;
                },
              ),
            ),
        ],
      ),
    );
  }

  Key? _chipKey(ApprovalCategory category) => switch (category) {
        ApprovalCategory.academic => QaTestKeys.approvalTypeFilterAcademic,
        ApprovalCategory.attendance => QaTestKeys.approvalTypeFilterAttendance,
        ApprovalCategory.leave => QaTestKeys.approvalTypeFilterLeave,
        ApprovalCategory.finance => QaTestKeys.approvalTypeFilterFinance,
        ApprovalCategory.inventory => QaTestKeys.approvalTypeFilterInventory,
        _ => null,
      };
}
