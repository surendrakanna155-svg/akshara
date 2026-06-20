import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../management_navigation.dart';
import '../management_models.dart';

class ManagementSubNav extends StatelessWidget {
  const ManagementSubNav({super.key, required this.current});

  final ManagementScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'management',
      semanticsLabel: 'Management module navigation',
      items: [
        for (final screen in kManagementNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('management', screen.label),
            label: screen.label,
            selected: screen == current,
            onTap: () {
              if (screen != current) {
                context.go(screen.route);
              }
            },
          ),
      ],
    );
  }
}
