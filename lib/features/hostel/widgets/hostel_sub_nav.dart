import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_navigation.dart';
import '../../../theme/spacing.dart';
import '../hostel_navigation.dart';
import '../hostel_models.dart';

class HostelSubNav extends StatelessWidget {
  const HostelSubNav({super.key, required this.current});

  final HostelScreen current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Hostel module navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final screen in kHostelNavScreens) ...[
              AksharaModuleSubNavTab(
                key: QaTestKeys.moduleSubNavTab('hostel', screen.label),
                label: screen.label,
                selected: screen == current,
                onTap: () {
                  if (screen != current) {
                    context.go(screen.route);
                  }
                },
              ),
              if (screen != kHostelNavScreens.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}
