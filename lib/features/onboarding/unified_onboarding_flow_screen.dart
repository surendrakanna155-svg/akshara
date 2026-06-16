import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/supported_languages.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import 'unified_onboarding_models.dart';
import 'unified_onboarding_provider.dart';

/// Unified school startup: Profile → Curriculum → … → Go Live (tenant-persisted).
class UnifiedOnboardingFlowScreen extends ConsumerStatefulWidget {
  const UnifiedOnboardingFlowScreen({super.key});

  @override
  ConsumerState<UnifiedOnboardingFlowScreen> createState() =>
      _UnifiedOnboardingFlowScreenState();
}

class _UnifiedOnboardingFlowScreenState
    extends ConsumerState<UnifiedOnboardingFlowScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(unifiedOnboardingProvider);
    final notifier = ref.read(unifiedOnboardingProvider.notifier);

    return Scaffold(
      key: QaTestKeys.unifiedOnboardingScreen,
      appBar: AppBar(title: Text('School setup · ${state.currentStep.label}')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          LinearProgressIndicator(
            value: (UnifiedOnboardingStep.values.indexOf(state.currentStep) + 1) /
                UnifiedOnboardingStep.values.length,
          ),
          if (state.isLoading) ...[
            const SizedBox(height: AksharaSpacing.s2),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          _StepBody(state: state, notifier: notifier),
          if (state.goLiveValidationErrors.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s3),
            AksharaInsightCard(
              message: state.goLiveValidationErrors.join('\n'),
              actionLabel: 'Fix issues',
              onAction: null,
            ),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          Row(
            children: [
              if (state.currentStep != UnifiedOnboardingStep.schoolProfile)
                OutlinedButton(
                  onPressed: state.isLoading ? null : notifier.previousStep,
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (state.currentStep == UnifiedOnboardingStep.review)
                FilledButton(
                  key: QaTestKeys.unifiedOnboardingGoLiveButton,
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final ok = await notifier.goLive();
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Complete required fields before go-live'),
                              ),
                            );
                          }
                        },
                  child: const Text('Go Live'),
                )
              else if (state.currentStep != UnifiedOnboardingStep.goLive)
                FilledButton(
                  key: QaTestKeys.unifiedOnboardingContinueButton,
                  onPressed: state.isLoading ? null : notifier.nextStep,
                  child: const Text('Continue'),
                ),
            ],
          ),
          if (state.lastSavedAt != null) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Saved server-side · ${state.lastSavedAt}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.state, required this.notifier});

  final UnifiedOnboardingState state;
  final UnifiedOnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return switch (state.currentStep) {
      UnifiedOnboardingStep.schoolProfile =>
        _SchoolProfileStep(state: state, notifier: notifier),
      UnifiedOnboardingStep.curriculum => DropdownButtonFormField<String>(
          value: state.curriculum,
          decoration: const InputDecoration(
            labelText: 'Board / curriculum',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'CBSE', child: Text('CBSE')),
            DropdownMenuItem(value: 'ICSE', child: Text('ICSE')),
            DropdownMenuItem(value: 'State Board', child: Text('State Board')),
          ],
          onChanged: (v) {
            if (v != null) notifier.updateCurriculum(v);
          },
        ),
      UnifiedOnboardingStep.academicStructure => Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Academic year',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: state.academicYear),
              onChanged: notifier.updateAcademicYear,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Classes (comma-separated)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: state.classes.join(', ')),
              onChanged: notifier.updateClasses,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Sections (comma-separated)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: state.sections.join(', ')),
              onChanged: notifier.updateSections,
            ),
          ],
        ),
      UnifiedOnboardingStep.fees => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: state.feeModel.isEmpty ? 'term_wise' : state.feeModel,
              decoration: const InputDecoration(
                labelText: 'Fee model',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'term_wise', child: Text('Term-wise')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'annual', child: Text('Annual')),
              ],
              onChanged: (v) {
                if (v != null) notifier.updateFeeModel(v);
              },
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Fee categories (comma-separated)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(
                text: state.feeCategories.isEmpty
                    ? 'Tuition, Transport, Activity'
                    : state.feeCategories.join(', '),
              ),
              onChanged: notifier.updateFeeCategories,
            ),
          ],
        ),
      UnifiedOnboardingStep.branding => Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Logo URL (optional)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: state.logoUrl),
              onChanged: notifier.updateLogoUrl,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Primary theme colour',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: state.themePrimary),
              onChanged: notifier.updateThemePrimary,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Secondary theme colour',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: state.themeSecondary),
              onChanged: notifier.updateThemeSecondary,
            ),
          ],
        ),
      UnifiedOnboardingStep.language => DropdownButtonFormField<String>(
          value: state.defaultLanguage,
          decoration: const InputDecoration(
            labelText: 'Default parent language',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final lang in AksharaLanguage.values)
              DropdownMenuItem(value: lang.code, child: Text(lang.displayName)),
          ],
          onChanged: (v) {
            if (v != null) notifier.updateDefaultLanguage(v);
          },
        ),
      UnifiedOnboardingStep.modules => Column(
          children: [
            for (final module in ['sis', 'finance', 'attendance', 'transport', 'library'])
              SwitchListTile(
                title: Text(module.toUpperCase()),
                value: state.modulesEnabled.contains(module),
                onChanged: (v) => notifier.toggleModule(module, v),
              ),
          ],
        ),
      UnifiedOnboardingStep.review => AksharaSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('School: ${state.schoolName.isEmpty ? '(not set)' : state.schoolName}'),
              Text('Board: ${state.board.isEmpty ? state.curriculum : state.board}'),
              Text('Address: ${state.address.isEmpty ? '(not set)' : state.address}'),
              Text('Contact: ${state.contactPhone} ${state.contactEmail}'),
              Text('Year: ${state.academicYear}'),
              Text('Classes: ${state.classes.join(', ')}'),
              Text('Sections: ${state.sections.join(', ')}'),
              Text('Fee model: ${state.feeModel.isEmpty ? '(not set)' : state.feeModel}'),
              Text('Fee categories: ${state.feeCategories.join(', ')}'),
              Text('Language: ${state.defaultLanguage}'),
              Text('Theme: ${state.themePrimary} / ${state.themeSecondary}'),
              Text('Modules: ${state.modulesEnabled.join(', ')}'),
            ],
          ),
        ),
      UnifiedOnboardingStep.goLive => AksharaSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key: QaTestKeys.unifiedOnboardingGoLiveSuccess,
                state.isLive
                    ? 'School is live. All admins see this configuration.'
                    : 'Complete review to go live.',
              ),
              if (state.provisionSummary != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  key: QaTestKeys.unifiedOnboardingProvisionSummary,
                  'Provisioned: profile, ${state.provisionSummary!.classCount} classes, '
                  '${state.provisionSummary!.sectionCount} sections, '
                  '${state.provisionSummary!.feeStructureCount} fee structures, branding.',
                ),
              ],
            ],
          ),
        ),
    };
  }
}

/// Profile fields use stable controllers so Patrol/device input persists to state.
class _SchoolProfileStep extends StatefulWidget {
  const _SchoolProfileStep({required this.state, required this.notifier});

  final UnifiedOnboardingState state;
  final UnifiedOnboardingNotifier notifier;

  @override
  State<_SchoolProfileStep> createState() => _SchoolProfileStepState();
}

class _SchoolProfileStepState extends State<_SchoolProfileStep> {
  late final TextEditingController _schoolName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _hydratedFromStore = false;

  @override
  void initState() {
    super.initState();
    _schoolName = TextEditingController();
    _address = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _schoolName.addListener(() => widget.notifier.updateSchoolName(_schoolName.text));
    _address.addListener(() => widget.notifier.updateAddress(_address.text));
    _phone.addListener(() => widget.notifier.updateContactPhone(_phone.text));
    _email.addListener(() => widget.notifier.updateContactEmail(_email.text));
  }

  @override
  void dispose() {
    _schoolName.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _applyHydratedState(UnifiedOnboardingState state) {
    if (_hydratedFromStore || !state.isHydrated) return;
    _hydratedFromStore = true;
    if (_schoolName.text.isEmpty && state.schoolName.isNotEmpty) {
      _schoolName.text = state.schoolName;
    }
    if (_address.text.isEmpty && state.address.isNotEmpty) {
      _address.text = state.address;
    }
    if (_phone.text.isEmpty && state.contactPhone.isNotEmpty) {
      _phone.text = state.contactPhone;
    }
    if (_email.text.isEmpty && state.contactEmail.isNotEmpty) {
      _email.text = state.contactEmail;
    }
  }

  @override
  Widget build(BuildContext context) {
    _applyHydratedState(widget.state);

    return Column(
      children: [
        TextField(
          key: QaTestKeys.unifiedOnboardingSchoolNameField,
          decoration: const InputDecoration(
            labelText: 'School name',
            border: OutlineInputBorder(),
          ),
          controller: _schoolName,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          key: QaTestKeys.unifiedOnboardingAddressField,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          controller: _address,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          key: QaTestKeys.unifiedOnboardingContactPhoneField,
          decoration: const InputDecoration(
            labelText: 'Contact phone',
            border: OutlineInputBorder(),
          ),
          controller: _phone,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          key: QaTestKeys.unifiedOnboardingContactEmailField,
          decoration: const InputDecoration(
            labelText: 'Contact email',
            border: OutlineInputBorder(),
          ),
          controller: _email,
        ),
      ],
    );
  }
}
