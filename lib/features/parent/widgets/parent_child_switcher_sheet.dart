import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../router/route_names.dart';
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Switch child',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            for (final child in children)
              ListTile(
                leading: CircleAvatar(
                  child: Text(child.name.isNotEmpty ? child.name[0] : '?'),
                ),
                title: Text(child.name),
                subtitle: Text('Class ${child.classLabel}'),
                trailing: auth.selectedChild?.id == child.id
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () async {
                  await selectParentActiveChild(ref, child);
                  ref.invalidate(parentProfileFutureProvider);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
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
