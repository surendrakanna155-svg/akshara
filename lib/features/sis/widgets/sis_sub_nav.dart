import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/surface_backend_gate.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../sis_navigation.dart';
import '../sis_models.dart';

class SisSubNav extends ConsumerWidget {
  const SisSubNav({super.key, required this.current});

  final SisScreen current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaModuleSubNav(
      moduleKey: 'sis',
      semanticsLabel: 'Student SIS module navigation',
      items: [
        // P0-CODE-2: drop tabs for backend-less surfaces hidden in a live build.
        for (final screen in kSisNavScreens)
          if (!isBackendLessSurfaceHidden(ref, screen.route))
            AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('sis', screen.label),
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
