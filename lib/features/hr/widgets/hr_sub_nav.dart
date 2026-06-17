import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../../../theme/spacing.dart';
import '../hr_navigation.dart';
import '../hr_models.dart';

class HrSubNav extends StatelessWidget {
  const HrSubNav({super.key, required this.current});

  final HrScreen current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'HR module navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final screen in kHrNavScreens) ...[
              AksharaModuleSubNavTab(
                key: QaTestKeys.moduleSubNavTab('hr', screen.label),
                label: screen.label,
                selected: screen == current,
                onTap: () {
                  if (screen != current) {
                    context.go(screen.route);
                  }
                },
              ),
              if (screen != kHrNavScreens.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}
