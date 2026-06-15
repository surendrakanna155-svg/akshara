import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import 'organization_builder_models.dart';
import 'organization_builder_mutations_provider.dart';
import 'organization_builder_providers.dart';

class OrganizationBuilderPreviewScreen extends ConsumerWidget {
  const OrganizationBuilderPreviewScreen({
    super.key,
    required this.draftId,
  });

  final String draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewState = ref.watch(configPreviewProvider(draftId));
    final provisionState = ref.watch(startProvisioningProvider);

    return Scaffold(
      key: QaTestKeys.organizationBuilderPreviewScreen,
      appBar: AppBar(
        title: const Text('Config Preview'),
      ),
      body: previewState.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) =>
            AksharaErrorState(message: 'Unable to load preview: $error'),
        data: (preview) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              preview.organizationName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('Pack: ${preview.packId}'),
            const SizedBox(height: 16),
            _Section(
              title: 'Modules',
              child: _ModuleList(modules: preview.modules),
            ),
            _Section(
              title: 'Roles',
              child: _RoleList(roles: preview.roles),
            ),
            _Section(
              title: 'Dashboard Widgets',
              child: _WidgetList(widgets: preview.widgets),
            ),
            _Section(
              title: 'Workflows',
              child: _WorkflowList(workflows: preview.workflows),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: QaTestKeys.organizationBuilderStartProvisioningButton,
              onPressed: provisionState.isLoading
                  ? null
                  : () => _startProvisioning(context, ref, preview),
              icon: provisionState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch_outlined),
              label: const Text('Approve & provision'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startProvisioning(
    BuildContext context,
    WidgetRef ref,
    ConfigPreview preview,
  ) async {
    final job = await ref
        .read(startProvisioningProvider.notifier)
        .execute(draftId: preview.draftId);
    if (job == null || !context.mounted) return;
    context.push(
      '${RouteNames.organizationBuilderProvisioning}?jobId=${job.id}',
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.modules});

  final List<ConfigModuleItem> modules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final module in modules)
          ListTile(
            key: QaTestKeys.organizationBuilderPreviewModule(module.id),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              module.enabled ? Icons.check_circle : Icons.cancel_outlined,
              color: module.enabled ? Colors.green : Colors.grey,
            ),
            title: Text(module.name),
            trailing: module.isNew
                ? const Chip(label: Text('NEW'))
                : null,
          ),
      ],
    );
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList({required this.roles});

  final List<ConfigRoleItem> roles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final role in roles)
          ListTile(
            key: QaTestKeys.organizationBuilderPreviewRole(role.id),
            contentPadding: EdgeInsets.zero,
            title: Text(role.name),
            trailing: Text('${role.permissionCount} permissions'),
          ),
      ],
    );
  }
}

class _WidgetList extends StatelessWidget {
  const _WidgetList({required this.widgets});

  final List<ConfigWidgetItem> widgets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final widget in widgets)
          ListTile(
            key: QaTestKeys.organizationBuilderPreviewWidget(widget.id),
            contentPadding: EdgeInsets.zero,
            title: Text(widget.widgetName),
            subtitle: Text(widget.role),
          ),
      ],
    );
  }
}

class _WorkflowList extends StatelessWidget {
  const _WorkflowList({required this.workflows});

  final List<ConfigWorkflowItem> workflows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final workflow in workflows)
          ListTile(
            key: QaTestKeys.organizationBuilderPreviewWorkflow(workflow.id),
            contentPadding: EdgeInsets.zero,
            title: Text(workflow.name),
            subtitle: Text('Trigger: ${workflow.trigger}'),
          ),
      ],
    );
  }
}
