import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../transport_navigation.dart';
import '../transport_models.dart';

class TransportSubNav extends StatelessWidget {
  const TransportSubNav({super.key, required this.current});

  final TransportScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'transport',
      semanticsLabel: 'Transport module navigation',
      items: [
        for (final screen in kTransportNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('transport', screen.label),
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
