import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../theme/spacing.dart';
import '../admin_content_scaffold.dart';
import '../admin_navigation_provider.dart';
import '../admin_shell.dart';
import '../models/admin_nav_models.dart';

/// Placeholder screen for an ERP module route group (no feature screens yet).
class AdminModulePlaceholderScreen extends StatelessWidget {
  const AdminModulePlaceholderScreen({
    super.key,
    required this.module,
    this.showFilterBar = false,
  });

  final AdminModule module;
  final bool showFilterBar;

  @override
  Widget build(BuildContext context) {
    final info = kAdminModuleInfo[module]!;

    return AdminContentScaffold(
      breadcrumbs: adminBreadcrumbsForModule(module),
      showFilterBar: showFilterBar,
      onMenuTap: adminShellMenuTap(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AksharaSpacing.s6),
          AksharaSectionHeader(title: info.title),
          const SizedBox(height: AksharaSpacing.s4),
          AksharaEmptyState(
            message: info.description,
            icon: Icons.construction_outlined,
          ),
        ],
      ),
    );
  }
}
