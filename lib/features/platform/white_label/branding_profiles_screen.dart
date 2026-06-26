import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import 'white_label_models.dart';
import 'white_label_mutations_provider.dart';
import 'white_label_providers.dart';

class BrandingProfilesScreen extends ConsumerWidget {
  const BrandingProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(brandingProfilesProvider);
    return Scaffold(
      key: QaTestKeys.whiteLabelBrandingScreen,
      appBar: AppBar(title: const Text('Branding Profiles')),
      body: profiles.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final profile = list[index];
            return ListTile(
              key: QaTestKeys.whiteLabelBrandingTile(profile.id),
              title: Text(profile.name),
              subtitle: Text(profile.primaryColor),
              trailing: profile.isDefault
                  ? const Chip(label: Text('Default'))
                  : null,
            );
          },
        ),
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(brandingProfilesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: QaTestKeys.whiteLabelSaveBrandingButton,
        onPressed: () {
          ref.read(saveBrandingProfileProvider.notifier).execute(
                profile: const BrandingProfile(
                  id: 'wl_profile_new',
                  name: 'New Brand',
                  primaryColor: '#4CAF50',
                  accentColor: '#FF9800',
                  isDefault: false,
                ),
              );
        },
        child: const Icon(Icons.save),
      ),
    );
  }
}
