import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../finance_navigation.dart';
import '../finance_models.dart';

/// Sub-navigation for Finance Phase 1 screens (collapses to "More" on phones).
class FinanceSubNav extends StatelessWidget {
  const FinanceSubNav({
    super.key,
    required this.current,
  });

  final FinanceScreen current;

  @override
  Widget build(BuildContext context) {
    return AksharaModuleSubNav(
      moduleKey: 'finance',
      semanticsLabel: 'Finance module navigation',
      items: [
        for (final screen in kFinanceNavScreens)
          AksharaModuleSubNavItem(
            itemKey: QaTestKeys.moduleSubNavTab('finance', screen.label),
            label: screen.label,
            selected: screen == current ||
                (current == FinanceScreen.collectionDetail &&
                    screen == FinanceScreen.collections),
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
