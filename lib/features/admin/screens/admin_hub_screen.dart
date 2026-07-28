import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../shared/widgets/premium/akshara_line_art.dart';
import '../../../shared/widgets/premium/akshara_workspace_landing.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/workspace/workspace_providers.dart';
import '../admin_content_scaffold.dart';
import '../admin_navigation_provider.dart';
import '../admin_shell.dart';
import '../models/admin_nav_models.dart';
import '../workspace_landing_config.dart';
import '../../../shared/widgets/workspace_switcher.dart';

/// Functional ERP hub — shows the active workspace's modules only
/// (USER → ROLE → WORKSPACE → TASK), with a switcher for multi-hat users.
class AdminHubScreen extends ConsumerWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(workspaceScopedNavDestinationsProvider);
    final modules = destinations
        .where((destination) => destination.module != AdminModule.admin)
        .toList(growable: false);
    final workspace = ref.watch(activeWorkspaceProvider);
    final hasMultiple = ref.watch(hasMultipleWorkspacesProvider);

    final title = workspace?.title ?? 'Admin Hub';
    final subtitle = hasMultiple
        ? 'You are in your ${workspace?.shortTitle ?? ''} workspace. Switch hats anytime.'
        : 'Jump to a module you are authorized to access.';
    final landing =
        workspace == null ? null : kWorkspaceLandingConfig[workspace.id];

    return AdminContentScaffold(
      key: QaTestKeys.adminHubScreen,
      breadcrumbs: adminBreadcrumbsForModule(AdminModule.admin),
      showFilterBar: false,
      onMenuTap: adminShellMenuTap(context),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.admin,
        watermark: AksharaWatermarkMotif.sparkles,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AksharaSpacing.s6),
            if (hasMultiple) ...[
              const WorkspaceSwitcher(),
              const SizedBox(height: AksharaSpacing.s6),
            ],
            AksharaWorkspaceLanding(
              workspaceName: title,
              motif: landing?.motif ?? AksharaMotif.graduationCap,
              eyebrow: landing?.eyebrow ?? 'WORKSPACE',
              stats: landing?.stats ?? const <AksharaWorkspaceStat>[],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Text(
              subtitle,
              style: context.aksharaText.bodyMedium,
            ),
            const SizedBox(height: AksharaSpacing.s6),
            // The cards used to be a fixed 220dp wide. A typical phone is ~411dp
            // of logical width, so two cards plus the gap (456dp) never fit —
            // every row held ONE 220dp card and left ~46% of the screen as dead
            // gutter, on the first screen a principal sees. Size the column to
            // the space actually available: two-up (or more) on a wide screen,
            // full-bleed when only one fits.
            LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = AksharaSpacing.s4;
                const double minCardWidth = 220;
                final int columns = ((constraints.maxWidth + spacing) /
                        (minCardWidth + spacing))
                    .floor()
                    .clamp(1, 4);
                final double cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final destination in modules)
                      _ModuleCard(
                        destination: destination,
                        width: cardWidth,
                        onTap: () => context.go(destination.route),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.destination,
    required this.width,
    required this.onTap,
  });

  final AdminNavDestination destination;

  /// Computed by the parent from the available width, so a card never leaves a
  /// dead gutter beside it on a phone.
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: width,
      child: Material(
        key: QaTestKeys.adminHubModuleCard(destination.label),
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s4),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s4),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AksharaSpacing.s3),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(destination.selectedIcon, color: colors.onPrimary),
                ),
                const SizedBox(height: AksharaSpacing.s4),
                Text(destination.label, style: context.aksharaText.titleSmall),
                const SizedBox(height: AksharaSpacing.s1),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: context.aksharaText.labelSmall
                          .copyWith(color: colors.primary),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: colors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
