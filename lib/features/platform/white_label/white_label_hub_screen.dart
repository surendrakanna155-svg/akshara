import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import 'white_label_providers.dart';

class WhiteLabelHubScreen extends ConsumerWidget {
  const WhiteLabelHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(whiteLabelCanViewProvider)) {
      return const Scaffold(body: Center(child: Text('Permission required.')));
    }
    final dashboard = ref.watch(whiteLabelDashboardProvider);
    return Scaffold(
      key: QaTestKeys.whiteLabelHubScreen,
      appBar: AppBar(title: const Text('White Label Platform')),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Active profile: ${data.activeConfiguration.brandingProfileId}',
              key: QaTestKeys.whiteLabelActiveConfig,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  key: QaTestKeys.whiteLabelBrandingLink,
                  onPressed: () => context.go(RouteNames.whiteLabelBranding),
                  child: const Text('Branding Profiles'),
                ),
                ElevatedButton(
                  key: QaTestKeys.whiteLabelThemeLink,
                  onPressed: () => context.go(RouteNames.whiteLabelTheme),
                  child: const Text('Themes'),
                ),
                ElevatedButton(
                  key: QaTestKeys.whiteLabelLogoLink,
                  onPressed: () => context.go(RouteNames.whiteLabelLogo),
                  child: const Text('Logos'),
                ),
                ElevatedButton(
                  key: QaTestKeys.whiteLabelDeploymentLink,
                  onPressed: () => context.go(RouteNames.whiteLabelDeployment),
                  child: const Text('Deployments'),
                ),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
