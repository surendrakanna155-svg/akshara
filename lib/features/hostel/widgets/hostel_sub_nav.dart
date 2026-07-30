import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/school_build_scope.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../hostel_navigation.dart';
import '../hostel_models.dart';

class HostelSubNav extends StatelessWidget {
  const HostelSubNav({super.key, required this.current});

  final HostelScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'hostel',
      semanticsLabel: 'Hostel module navigation',
      items: [
        // CODE-7 (residence-lite): drop scope-hidden tabs (leave / gate-pass)
        // so the sub-nav never shows a tab that routes to AccessDenied.
        for (final screen in kHostelNavScreens)
          if (!SchoolBuildScope.isRouteHidden(screen.route))
            AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('hostel', screen.label),
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
