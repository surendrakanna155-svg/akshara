@TestOn('mac-os')
library;

import 'package:akshara_erp/shared/widgets/premium/akshara_gradient_hero.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:akshara_erp/theme/spacing.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 P2-4 — persona-cohesive premium surfaces. Pins the greeting hero under
/// each persona theme so the accent visibly re-tones the hero (Parent=blue,
/// Student=emerald, Teacher=indigo) instead of the old fixed indigo→violet
/// brand. Proves the hero reads cohesively with the branded chrome.

class _PersonaHero extends StatelessWidget {
  const _PersonaHero({
    required this.accent,
    required this.title,
    this.brightness = Brightness.light,
  });

  final Color accent;
  final String title;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AksharaAppTheme.persona(
        brightness: brightness,
        accent: accent,
      ),
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: AksharaGradientHero(
              eyebrow: title,
              headline: 'Good morning, Anaya',
              pills: const [
                AksharaHeroPill(label: '96% attendance', tone: KpiAccent.success),
                AksharaHeroPill(label: '₹2,400 due', tone: KpiAccent.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  const viewport = Size(390, 760);

  for (final mode in const [
    (label: 'light', brightness: Brightness.light),
    (label: 'dark', brightness: Brightness.dark),
  ]) {
    testWidgets('DS V2 persona heroes · ${mode.label}', (tester) async {
      suppressGoldenOverflowErrors();
      useGoldenViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.brightness == Brightness.dark
              ? AksharaAppTheme.dark()
              : AksharaAppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _PersonaHero(
                    accent: AksharaPersonaAccent.parent,
                    title: 'PARENT',
                    brightness: mode.brightness,
                  ),
                  _PersonaHero(
                    accent: AksharaPersonaAccent.student,
                    title: 'STUDENT',
                    brightness: mode.brightness,
                  ),
                  _PersonaHero(
                    accent: AksharaPersonaAccent.teacher,
                    title: 'TEACHER',
                    brightness: mode.brightness,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          goldenFileName('ds_v2_persona_heroes_${mode.label}', '390x760'),
        ),
      );
    });
  }
}
