import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../core/workflow/workflow_models.dart';
import '../../shared/widgets/widgets.dart';
import '../management/management_models.dart';
import '../management/widgets/management_module_scaffold.dart';
import 'workflow_automation_mutations_provider.dart';
import 'workflow_automation_providers.dart';

class WorkflowAutomationScreen extends ConsumerStatefulWidget {
  const WorkflowAutomationScreen({super.key});

  @override
  ConsumerState<WorkflowAutomationScreen> createState() => _WorkflowAutomationScreenState();
}

class _WorkflowAutomationScreenState extends ConsumerState<WorkflowAutomationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definitions = ref.watch(workflowDefinitionsProvider);
    final instances = ref.watch(workflowInstancesProvider);
    final jobs = ref.watch(scheduledWorkflowJobsProvider);
    final escalations = ref.watch(escalatedWorkflowInstancesProvider);
    final mutationState = ref.watch(workflowAutomationMutationsProvider);

    return ManagementModuleScaffold(
      key: QaTestKeys.workflowAutomationScreen,
      screen: ManagementScreen.workflowAutomation,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Workflow Automation Platform',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            tabs: const <Tab>[
              Tab(text: 'Rules'),
              Tab(text: 'Active'),
              Tab(text: 'Escalations'),
              Tab(text: 'Schedule'),
            ],
          ),
          const SizedBox(height: 12),
          if (mutationState.isLoading) const LinearProgressIndicator(),
          SizedBox(
            height: 560,
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                definitions.when(
                  data: (rows) => _RulesTab(definitions: rows),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('$error')),
                ),
                instances.when(
                  data: (rows) => _ActiveTab(instances: rows),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('$error')),
                ),
                _EscalationsTab(instances: escalations),
                jobs.when(
                  data: (rows) => _ScheduleTab(
                    jobs: rows,
                    onRunNow: () => ref
                        .read(workflowAutomationMutationsProvider.notifier)
                        .runScheduledJobsNow(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('$error')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.definitions});

  final List<WorkflowDefinition> definitions;

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) {
      return const AksharaErrorState(
        message: 'No workflow rules found.',
        icon: Icons.rule_outlined,
      );
    }
    return ListView.builder(
      itemCount: definitions.length,
      itemBuilder: (context, index) {
        final definition = definitions[index];
        return ListTile(
          title: Text(definition.name),
          subtitle: Text('${definition.module} · ${definition.rules.length} rules'),
          trailing: Icon(
            definition.enabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
          ),
        );
      },
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab({required this.instances});

  final List<WorkflowInstance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (instances.isEmpty) {
      return const Center(child: Text('No active workflow instances.'));
    }
    return ListView.builder(
      itemCount: instances.length,
      itemBuilder: (context, index) {
        final instance = instances[index];
        return ListTile(
          title: Text(instance.definitionId),
          subtitle: Text('Status: ${instance.status.name} · Assignee: ${instance.currentAssigneeRole}'),
          trailing: AksharaManageAction(
            permission: Permission.manageWorkflowAutomation,
            child: TextButton(
              onPressed: () {
                ref.read(workflowAutomationMutationsProvider.notifier).executeAction(
                      instanceId: instance.id,
                      transitionAction: 'route_school_admin',
                    );
              },
              child: const Text('Route'),
            ),
          ),
        );
      },
    );
  }
}

class _EscalationsTab extends StatelessWidget {
  const _EscalationsTab({required this.instances});

  final List<WorkflowInstance> instances;

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty) {
      return const Center(child: Text('No escalations pending.'));
    }
    return ListView(
      children: [
        for (final instance in instances)
          ListTile(
            title: Text(instance.definitionId),
            subtitle: Text(
              'Level ${instance.escalationLevel} · ${instance.currentAssigneeRole}',
            ),
          ),
      ],
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.jobs,
    required this.onRunNow,
  });

  final List<ScheduledWorkflowJob> jobs;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: QaTestKeys.workflowRunScheduledNowButton,
            onPressed: onRunNow,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Run scheduled now'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: jobs.isEmpty
              ? const Center(child: Text('No scheduled jobs configured.'))
              : ListView(
                  children: [
                    for (final job in jobs)
                      ListTile(
                        title: Text(job.definitionId),
                        subtitle: Text('Scheduled: ${job.scheduledAt}'),
                        trailing: Icon(job.enabled ? Icons.schedule : Icons.pause_circle),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
