import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../library_navigation.dart';
import '../library_models.dart';

class LibrarySubNav extends StatelessWidget {
  const LibrarySubNav({super.key, required this.current});

  final LibraryScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'library',
      semanticsLabel: 'Library module navigation',
      items: [
        for (final screen in kLibraryNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('library', screen.label),
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
