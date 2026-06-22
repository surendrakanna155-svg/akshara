import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_navigation.dart';
import '../control_center_navigation.dart';
import '../control_center_models.dart';

class ControlCenterSubNav extends StatelessWidget {
  const ControlCenterSubNav({super.key, required this.current});

  final ControlCenterScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'controlCenter',
      semanticsLabel: 'Control Center module navigation',
      items: [
        for (final screen in kControlCenterNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('controlCenter', screen.label),
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
