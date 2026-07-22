@TestOn('mac-os')
library;

import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_kpi_card.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_status_chip.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/spacing.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// DS V2 — states & data gallery. Pins the premium rendering of the semantic
/// data components (status chips · KPI tiles · empty state · loading state) in
/// Light + Dark, complementing the controls gallery (P2-3). Visual safety net
/// for the shared component library's "states" surfaces.
class _StatesGallery extends StatelessWidget {
  const _StatesGallery();

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
                'STATUS CHIPS',
                const Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s2,
                  children: [
                    AksharaStatusChip(
                      label: 'Paid',
                      tone: KpiAccent.success,
                      size: AksharaStatusChipSize.standard,
                    ),
                    AksharaStatusChip(
                      label: 'Due',
                      tone: KpiAccent.warning,
                      size: AksharaStatusChipSize.standard,
                    ),
                    AksharaStatusChip(
                      label: 'Overdue',
                      tone: KpiAccent.error,
                      size: AksharaStatusChipSize.standard,
                    ),
                    AksharaStatusChip(
                      label: 'Enrolled',
                      tone: KpiAccent.primary,
                      size: AksharaStatusChipSize.standard,
                    ),
                    AksharaStatusChip(
                      label: 'Draft',
                      tone: KpiAccent.neutral,
                      size: AksharaStatusChipSize.standard,
                    ),
                  ],
                ),
              ),
              section(
                'KPI TILES',
                const Row(
                  children: [
                    Expanded(
                      child: AksharaKpiCard(
                        value: '96%',
                        subtitle: 'Attendance',
                        accent: KpiAccent.success,
                        icon: Icons.check_circle_outline,
                        style: AksharaKpiCardStyle.filled,
                        detail: '+2% vs last term',
                      ),
                    ),
                    SizedBox(width: AksharaSpacing.s3),
                    Expanded(
                      child: AksharaKpiCard(
                        value: '₹4,500',
                        subtitle: 'Fees due',
                        accent: KpiAccent.warning,
                        icon: Icons.payments_outlined,
                        style: AksharaKpiCardStyle.filled,
                      ),
                    ),
                  ],
                ),
              ),
              section(
                'EMPTY',
                const AksharaEmptyState(
                  title: 'All caught up',
                  message: 'No notices right now — new ones will appear here.',
                  icon: Icons.campaign_outlined,
                  compact: true,
                ),
              ),
              section(
                'LOADING',
                const SizedBox(
                  height: 96,
                  child: AksharaLoadingState(semanticLabel: 'Loading results'),
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
  const viewport = Size(390, 760);

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('DS V2 states gallery · ${mode.label}', (tester) async {
      suppressGoldenOverflowErrors();
      useGoldenViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.dark ? AksharaAppTheme.dark() : AksharaAppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: const _StatesGallery(),
        ),
      );
      // The loading state's spinner animates forever, so pumpAndSettle would
      // time out — pump a fixed duration for a deterministic frame instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(_StatesGallery),
        matchesGoldenFile(
          goldenFileName('ds_v2_states_gallery_${mode.label}', '390x760'),
        ),
      );
    });
  }
}
