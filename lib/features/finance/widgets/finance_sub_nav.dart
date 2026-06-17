import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../../../theme/spacing.dart';
import '../finance_navigation.dart';
import '../finance_models.dart';

/// Horizontal sub-navigation for Finance Phase 1 screens.
class FinanceSubNav extends StatelessWidget {
  const FinanceSubNav({
    super.key,
    required this.current,
  });

  final FinanceScreen current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Finance module navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final screen in kFinanceNavScreens) ...[
              AksharaModuleSubNavTab(
                key: QaTestKeys.moduleSubNavTab('finance', screen.label),
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
              if (screen != kFinanceNavScreens.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}
