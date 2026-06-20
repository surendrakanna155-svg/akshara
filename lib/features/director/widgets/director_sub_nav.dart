import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../director_navigation.dart';

class DirectorSubNav extends StatelessWidget {
  const DirectorSubNav({super.key, required this.current});

  final DirectorScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'director',
      semanticsLabel: 'Director module navigation',
      items: [
        for (final screen in kDirectorNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('director', screen.label),
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
