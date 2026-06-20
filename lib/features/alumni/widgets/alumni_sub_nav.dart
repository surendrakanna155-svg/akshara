import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../alumni_navigation.dart';
import '../alumni_models.dart';

class AlumniSubNav extends StatelessWidget {
  const AlumniSubNav({super.key, required this.current});

  final AlumniScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'alumni',
      semanticsLabel: 'Alumni module navigation',
      items: [
        for (final screen in kAlumniNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('alumni', screen.label),
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
