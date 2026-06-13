import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/environment_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'auth_provider.dart';
import 'qa_login_persona.dart';

/// QA-only login — instant persona access without OTP (automation builds).
class QaLoginScreen extends ConsumerWidget {
  const QaLoginScreen({super.key});

  static const double _maxWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final qaEnabled = ref.watch(isQaLoginEnabledProvider);

    if (!qaEnabled) {
      return Scaffold(
        body: Center(
          child: Text(
            'QA login is disabled in this build.',
            style: text.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      key: QaTestKeys.qaLoginScreen,
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'QA Automation Login',
                    style: text.headlineSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(
                    'Select a persona — no OTP, no API. For emulator and Maestro only.',
                    style: text.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: QaLoginPersona.values.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AksharaSpacing.s3),
                      itemBuilder: (context, index) {
                        final persona = QaLoginPersona.values[index];
                        return FilledButton.tonal(
                          key: QaTestKeys.qaPersonaButton(persona.name),
                          onPressed: () => _signIn(context, ref, persona),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            alignment: Alignment.centerLeft,
                            shape: RoundedRectangleBorder(
                              borderRadius: AksharaRadius.button,
                            ),
                          ),
                          child: Text(
                            persona.buttonLabel,
                            style: text.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    QaLoginPersona persona,
  ) async {
    await ref.read(authProvider.notifier).signInQaPersona(persona);
    if (!context.mounted) {
      return;
    }
    context.go(homeRouteForQaPersona(persona));
  }
}
