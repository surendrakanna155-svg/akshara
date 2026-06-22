import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'white_label_providers.dart';

class DeploymentProfilesScreen extends ConsumerWidget {
  const DeploymentProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployments = ref.watch(deploymentProfilesProvider);
    return Scaffold(
      key: QaTestKeys.whiteLabelDeploymentScreen,
      appBar: AppBar(title: const Text('Deployment Profiles')),
      body: deployments.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final profile = list[index];
            return ListTile(
              key: QaTestKeys.whiteLabelDeploymentTile(profile.id),
              title: Text(profile.name),
              subtitle: Text('${profile.environment} — ${profile.domain}'),
              trailing: Text(profile.status),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
