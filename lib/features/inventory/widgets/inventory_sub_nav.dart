import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../inventory_navigation.dart';
import '../inventory_models.dart';

class InventorySubNav extends StatelessWidget {
  const InventorySubNav({super.key, required this.current});

  final InventoryScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'inventory',
      semanticsLabel: 'Inventory module navigation',
      items: [
        for (final screen in kInventoryNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('inventory', screen.label),
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
