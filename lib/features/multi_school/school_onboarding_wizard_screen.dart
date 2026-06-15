import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'multi_school_models.dart';
import 'multi_school_mutations_provider.dart';

class SchoolOnboardingWizardScreen extends ConsumerStatefulWidget {
  const SchoolOnboardingWizardScreen({super.key});

  @override
  ConsumerState<SchoolOnboardingWizardScreen> createState() =>
      _SchoolOnboardingWizardScreenState();
}

class _SchoolOnboardingWizardScreenState
    extends ConsumerState<SchoolOnboardingWizardScreen> {
  final _schoolNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _planNameController = TextEditingController(text: 'Growth');
  final _countryController = TextEditingController(text: 'India');
  final _capacityController = TextEditingController(text: '1200');
  bool _activateNow = true;
  bool _completed = false;
  int _step = 0;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _planNameController.dispose();
    _countryController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(completeOnboardingProvider);
    return Scaffold(
      key: QaTestKeys.multiSchoolOnboardingWizardScreen,
      appBar: AppBar(title: const Text('School Onboarding Wizard')),
      body: Column(
        children: [
          Expanded(
            child: Stepper(
              currentStep: _step,
              controlsBuilder: (_, __) => const SizedBox.shrink(),
              steps: [
          Step(
            title: const Text('Basics'),
            isActive: _step == 0,
            content: Column(
              children: [
                TextField(
                  key: QaTestKeys.multiSchoolOnboardingSchoolNameField,
                  controller: _schoolNameController,
                  decoration: const InputDecoration(labelText: 'School name'),
                ),
                TextField(
                  key: QaTestKeys.multiSchoolOnboardingContactNameField,
                  controller: _contactNameController,
                  decoration: const InputDecoration(labelText: 'Contact name'),
                ),
                TextField(
                  key: QaTestKeys.multiSchoolOnboardingContactEmailField,
                  controller: _contactEmailController,
                  decoration: const InputDecoration(labelText: 'Contact email'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Plan'),
            isActive: _step == 1,
            content: Column(
              children: [
                TextField(
                  key: QaTestKeys.multiSchoolOnboardingPlanField,
                  controller: _planNameController,
                  decoration: const InputDecoration(labelText: 'Plan'),
                ),
                TextField(
                  key: QaTestKeys.multiSchoolOnboardingCountryField,
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                TextField(
                  key: QaTestKeys.multiSchoolOnboardingCapacityField,
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Student capacity'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Activate'),
            isActive: _step == 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: QaTestKeys.multiSchoolOnboardingActivateSwitch,
                  contentPadding: EdgeInsets.zero,
                  value: _activateNow,
                  title: const Text('Activate immediately'),
                  onChanged: (value) => setState(() => _activateNow = value),
                ),
                if (_completed)
                  const ListTile(
                    key: QaTestKeys.multiSchoolOnboardingCompletedSnackbar,
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('School onboarding completed.'),
                  ),
              ],
            ),
          ),
        ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step < 2)
                    FilledButton(
                      key: QaTestKeys.multiSchoolOnboardingContinueButton,
                      onPressed: _nextStep,
                      child: const Text('Continue'),
                    ),
                  if (_step == 2)
                    FilledButton.icon(
                      key: QaTestKeys.multiSchoolOnboardingSubmitButton,
                      onPressed:
                          mutationState.isLoading || _completed ? null : _submit,
                      icon: mutationState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Complete onboarding'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_step < 2) {
      setState(() => _step += 1);
    }
  }

  Future<void> _submit() async {
    final now = DateTime.now();
    final draft = SchoolOnboardingDraft(
      id: 'draft_${now.microsecondsSinceEpoch}',
      schoolName: _schoolNameController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactEmail: _contactEmailController.text.trim(),
      planName: _planNameController.text.trim(),
      country: _countryController.text.trim(),
      studentCapacity: int.tryParse(_capacityController.text.trim()) ?? 0,
      activateNow: _activateNow,
      createdAt: now,
      updatedAt: now,
    );
    final result = await ref
        .read(completeOnboardingProvider.notifier)
        .execute(draft: draft);
    if (result == null || !mounted) return;
    setState(() => _completed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('School onboarding completed.')),
    );
  }
}
