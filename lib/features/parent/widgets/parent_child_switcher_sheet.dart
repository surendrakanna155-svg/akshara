import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_dialog.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../auth/auth_provider.dart';
import '../parent_active_child_provider.dart';
import '../profile/parent_profile_provider.dart';

Future<void> showParentChildSwitcherSheet(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authProvider);
  final children = auth.linkedChildren;
  if (children.length <= 1) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AksharaBottomSheetHeader(
              title: 'Switch child',
              subtitle: 'Select the student profile to view',
            ),
            for (final child in children)
              ListTile(
                key: QaTestKeys.parentChildSwitcherOption(child.id),
                leading: CircleAvatar(
                  backgroundColor: context.colors.primaryContainer,
                  child: Text(
                    child.name.isNotEmpty ? child.name[0] : '?',
                    style: TextStyle(color: context.colors.primary),
                  ),
                ),
                title: Text(child.name),
                subtitle: Text('Class ${child.classLabel}'),
                trailing: auth.selectedChild?.id == child.id
                    ? Icon(Icons.check_circle, color: context.colors.primary)
                    : null,
                onTap: () async {
                  await selectParentActiveChild(ref, child);
                  ref.invalidate(parentProfileFutureProvider);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(height: AksharaSpacing.s2),
          ],
        ),
      );
    },
  );
}

String parentExperienceHubPath(String studentId, {String? tab}) {
  final base = '${RouteNames.parentExperience}?studentId=$studentId';
  if (tab != null && tab.isNotEmpty) return '$base&tab=$tab';
  return base;
}
