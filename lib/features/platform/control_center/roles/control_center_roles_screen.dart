import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/akshara_error_state.dart';
import '../../../../shared/widgets/akshara_loading_state.dart';
import '../../../../shared/widgets/akshara_section_header.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// ACC-11 — Roles & Permissions.
class ControlCenterRolesScreen extends ConsumerWidget {
  const ControlCenterRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterRolesLoadingProvider);
    final isError = ref.watch(controlCenterRolesErrorProvider);
    final data = ref.watch(controlCenterRolesProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.roles,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        data: data,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required ControlCenterRolesData? data,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading platform roles'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load roles and permissions.',
      );
    }

    if (data == null) {
      return const AksharaErrorState(
        message: 'Roles data is not available.',
      );
    }

    final text = context.aksharaText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Platform roles'),
        const SizedBox(height: AksharaSpacing.s3),
        for (final role in data.roles) ...[
          _RoleCard(role: role),
          const SizedBox(height: AksharaSpacing.s3),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(title: 'Permission groups'),
        const SizedBox(height: AksharaSpacing.s3),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final group in data.permissionGroups)
                  Chip(label: Text(group, style: text.labelMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final PlatformRole role;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: '${role.name}, ${role.userCount} users',
      child: Card(
        elevation: 0,
        child: ListTile(
          title: Text(role.name, style: text.titleSmall),
          subtitle: Text(
            '${role.description}\n${role.permissionCount} permissions · ${role.userCount} users',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
          // STF-8: edit affordance removed — no client/backend write path
          // exists, so a no-op "Edit" misleads users. Roles remain read-only.
        ),
      ),
    );
  }
}
