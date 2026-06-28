import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/permissions.dart';
import '../../../../core/tenant/tenant_provider.dart';
import '../../../../core/repositories/repository_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../../../../core/errors/api_failure_mapper.dart';

/// v12.9 — Platform feature enablement per school (super admin only).
class ControlCenterFeaturesScreen extends ConsumerWidget {
  const ControlCenterFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(controlCenterProvidersDataProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.features,
      showFilterBar: false,
      body: data.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
          child: AksharaLoadingState(semanticLabel: 'Loading features'),
        ),
        error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
        data: (snapshot) => ListView(
          // The scaffold already hosts this body inside a SingleChildScrollView,
          // so the list must shrink-wrap and defer scrolling to the parent
          // (a bare ListView gets unbounded height here → layout assertion).
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            const AksharaWarningBanner(
              message: 'School admins cannot change platform feature flags or billing.',
            ),
            ...snapshot.features.map((f) => _FeatureTile(feature: f)),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({required this.feature});

  final FeatureEnablement feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AksharaManageAction(
      permission: Permission.managePlatformFeatures,
      child: SwitchListTile(
        title: Text(feature.featureKey),
        subtitle: Text('School ${feature.schoolId}'),
        value: feature.enabled,
        onChanged: (enabled) async {
          await ref.read(controlCenterRepositoryProvider).setFeatureEnablement(
                query: ref.read(repositoryQueryProvider),
                schoolId: feature.schoolId,
                featureKey: feature.featureKey,
                enabled: enabled,
              );
          ref.invalidate(controlCenterProvidersDataProvider);
        },
      ),
    );
  }
}
