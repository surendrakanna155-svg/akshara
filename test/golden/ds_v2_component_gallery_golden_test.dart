@TestOn('mac-os')
library;

import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/spacing.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 — component-gallery goldens. Pins the premium, branded rendering of the
/// core shared controls (buttons · chips · input · segmented button) in BOTH
/// Light and Dark so a control regression is caught deliberately. Most screens
/// that use these controls (exams, events, leave, messages…) have no golden of
/// their own — this gallery is their visual safety net.
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    Widget section(String title, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: text.labelMedium.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            child,
            const SizedBox(height: AksharaSpacing.s5),
          ],
        );

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section(
                'BUTTONS',
                Wrap(
                  spacing: AksharaSpacing.s3,
                  runSpacing: AksharaSpacing.s3,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('Pay now')),
                    FilledButton.tonal(
                      onPressed: () {},
                      style: AksharaAppTheme.tonalButtonStyle(context),
                      child: const Text('Review'),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Later'),
                    ),
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                  ],
                ),
              ),
              section(
                'CHIPS',
                Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s2,
                  children: [
                    FilterChip(
                      selected: true,
                      onSelected: (_) {},
                      label: const Text('This term'),
                    ),
                    FilterChip(
                      selected: false,
                      onSelected: (_) {},
                      label: const Text('Last term'),
                    ),
                    const Chip(label: Text('Class 8-A')),
                  ],
                ),
              ),
              section(
                'INPUT',
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Search students',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              section(
                'SEGMENTED',
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Due')),
                    ButtonSegment(value: 1, label: Text('Paid')),
                    ButtonSegment(value: 2, label: Text('All')),
                  ],
                  selected: const {0},
                  onSelectionChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  const viewport = Size(390, 640);

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('DS V2 component gallery · ${mode.label}', (tester) async {
      suppressGoldenOverflowErrors();
      useGoldenViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.dark ? AksharaAppTheme.dark() : AksharaAppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: const _Gallery(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_Gallery),
        matchesGoldenFile(
          goldenFileName('ds_v2_component_gallery_${mode.label}', '390x640'),
        ),
      );
    });
  }
}
