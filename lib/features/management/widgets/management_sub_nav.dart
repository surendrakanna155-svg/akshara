import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/surface_backend_gate.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../management_navigation.dart';
import '../management_models.dart';

class ManagementSubNav extends ConsumerWidget {
  const ManagementSubNav({super.key, required this.current});

  final ManagementScreen current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaModuleSubNav(
      moduleKey: 'management',
      semanticsLabel: 'Management module navigation',
      items: [
        // P0-CODE-2: drop tabs for backend-less surfaces hidden in a live build.
        for (final screen in kManagementNavScreens)
          if (!isBackendLessSurfaceHidden(ref, screen.route))
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
