import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../admin_content_scaffold.dart';
import '../admin_navigation_provider.dart';
import '../admin_shell.dart';
import '../models/admin_nav_models.dart';

/// Functional ERP hub — links to permission-filtered module destinations.
class AdminHubScreen extends ConsumerWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(adminNavDestinationsProvider);
    final modules = destinations
        .where((destination) => destination.module != AdminModule.admin)
        .toList(growable: false);

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
            const AksharaSectionHeader(title: 'Admin Hub'),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            'Jump to an ERP module you are authorized to access.',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s6),
          Wrap(
            spacing: AksharaSpacing.s4,
            runSpacing: AksharaSpacing.s4,
            children: [
              for (final destination in modules)
                _ModuleCard(
                  destination: destination,
                  onTap: () => context.go(destination.route),
                ),
            ],
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
    required this.onTap,
  });

  final AdminNavDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 220,
      child: Material(
        key: QaTestKeys.adminHubModuleCard(destination.label),
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(destination.icon, color: colors.primary),
                const SizedBox(height: AksharaSpacing.s3),
                Text(destination.label, style: context.aksharaText.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
