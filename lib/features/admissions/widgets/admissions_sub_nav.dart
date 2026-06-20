import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../admissions_navigation.dart';

/// Horizontal sub-navigation for Admissions Phase 1 screens.
class AdmissionsSubNav extends StatelessWidget {
  const AdmissionsSubNav({
    super.key,
    required this.current,
  });

  final AdmissionsScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'admissions',
      semanticsLabel: 'Admissions module navigation',
      items: [
        for (final screen in kAdmissionsNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('admissions', screen.label),
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
