import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        for (final screen in kHostelNavScreens)
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
