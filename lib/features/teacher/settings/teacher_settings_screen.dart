import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/profile/widgets/profile_info_row.dart';

/// Teacher settings — gives the teacher persona an entry point for the shared,
/// persona-agnostic preferences (Appearance / theme, AI Assistant). The teacher
/// shell previously had no profile/settings screen, so the device-global dark-
/// mode toggle was unreachable from this persona (Phase C.2 known gap).
class TeacherSettingsScreen extends StatelessWidget {
  const TeacherSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: QaTestKeys.teacherSettingsScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: const AksharaAppBar(
        titleText: 'Settings',
        subtitle: 'Preferences for this device',
        trailingPadding: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s4,
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AksharaSectionHeader(
                  title: 'Preferences',
                  fixedHeight: false,
                  spacingBelow: AksharaSpacing.s3,
                ),
                ProfileInfoRow(
                  key: QaTestKeys.aiAssistantSettingsLink,
                  icon: Icons.psychology_outlined,
                  label: 'AI Assistant',
                  value: 'Choose how AI appears in the app',
                  onTap: () => context.push(RouteNames.aiAssistantSettings),
                ),
                const SizedBox(height: AksharaSpacing.s2),
                ProfileInfoRow(
                  key: QaTestKeys.appearanceSettingsLink,
                  icon: Icons.brightness_6_outlined,
                  label: 'Appearance',
                  value: 'Light, dark, or match your device',
                  onTap: () => context.push(RouteNames.appearanceSettings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
