import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/supported_languages.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/forms/forms.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'ai_school_builder_models.dart';
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
          AksharaStepIndicator(
            stepLabels: [
              for (final step in UnifiedOnboardingStep.values) step.label,
            ],
            currentIndex:
                UnifiedOnboardingStep.values.indexOf(state.currentStep),
          ),
          if (state.isLoading) ...[
            const SizedBox(height: AksharaSpacing.s2),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          const _OngoingOnboardingActionsCard(),
          const SizedBox(height: AksharaSpacing.s4),
          _AiQuickSetupCard(notifier: notifier, isBusy: state.isLoading),
          const SizedBox(height: AksharaSpacing.s4),
          _StepBody(state: state, notifier: notifier),
          if (state.goLiveValidationErrors.isNotEmpty) ...[
            const SizedBox(height: AksharaSpacing.s3),
            AksharaInsightCard(
              message: state.goLiveValidationErrors.join('\n'),
              actionLabel: 'Fix issues',
              onAction: () => notifier.setStep(_firstIncompleteStep(state)),
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
              style: context.aksharaText.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Maps go-live validation gaps to the earliest wizard step that fixes them,
/// so "Fix issues" jumps the user straight to the first incomplete section.
UnifiedOnboardingStep _firstIncompleteStep(UnifiedOnboardingState state) {
  if (state.schoolName.trim().isEmpty ||
      state.address.trim().isEmpty ||
      (state.contactPhone.trim().isEmpty &&
          state.contactEmail.trim().isEmpty) ||
      state.academicYear.trim().isEmpty) {
    return UnifiedOnboardingStep.schoolProfile;
  }
  if (state.board.trim().isEmpty && state.curriculum.trim().isEmpty) {
    return UnifiedOnboardingStep.curriculum;
  }
  if (state.classes.isEmpty || state.sections.isEmpty) {
    return UnifiedOnboardingStep.academicStructure;
  }
  if (state.feeModel.trim().isEmpty || state.feeCategories.isEmpty) {
    return UnifiedOnboardingStep.fees;
  }
  if (state.themePrimary.trim().isEmpty) {
    return UnifiedOnboardingStep.branding;
  }
  if (state.defaultLanguage.trim().isEmpty) {
    return UnifiedOnboardingStep.language;
  }
  return UnifiedOnboardingStep.schoolProfile;
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
          initialValue: state.curriculum,
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
              initialValue: state.feeModel.isEmpty ? 'term_wise' : state.feeModel,
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
          initialValue: state.defaultLanguage,
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

/// Gap-remediation #10 — `OnboardingHubScreen` (`/sis/onboarding`, invites +
/// student import) and `StudentOnboardingScreen` (`/admin/onboarding/students`)
/// are registered routes with NO menu/drawer entry point anywhere in the app —
/// reachable only by typing the URL. Neither is superseded by this wizard
/// (this screen is a one-time school-setup flow: profile/curriculum/fees/
/// branding/modules/go-live; it has no per-person invite or per-student import
/// UI), so they are genuinely needed, ongoing tools, not orphaned duplicates.
/// This card — shown on every step, since this screen (reached from Settings
/// → "Guided school onboarding") is itself the one place in the app that is
/// actually wired to a real nav entry — gives them a real, reachable path.
class _OngoingOnboardingActionsCard extends StatelessWidget {
  const _OngoingOnboardingActionsCard();

  @override
  Widget build(BuildContext context) {
    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ongoing onboarding', style: context.aksharaText.titleMedium),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            'Invite people and bring in student data any time — these are not '
            'one-time setup steps.',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_add_alt_outlined),
            title: const Text('Invite parents, teachers & students'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.onboardingHub),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Import / add students'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.studentOnboarding),
          ),
        ],
      ),
    );
  }
}

/// B7 — AI School Builder (Phase 1): one-tap entry that turns a short brief into
/// a complete, board-appropriate draft, applied into the wizard for review.
class _AiQuickSetupCard extends StatelessWidget {
  const _AiQuickSetupCard({required this.notifier, required this.isBusy});

  final UnifiedOnboardingNotifier notifier;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: AksharaSpacing.s2),
              Expanded(
                child: Text('AI Quick Setup', style: context.aksharaText.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            'Describe your school in a few words and let NIKSHA draft your '
            'classes, sections, fees, language and modules. You can review and '
            'edit everything before going live.',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: QaTestKeys.unifiedOnboardingAiPrefillButton,
              onPressed: isBusy ? null : () => _openBriefSheet(context),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Pre-fill with AI'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBriefSheet(BuildContext context) async {
    final brief = await showModalBottomSheet<SchoolBrief>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _AiBriefSheet(),
      ),
    );
    if (brief == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final meta = await notifier.aiPrefill(brief);
      if (!context.mounted) return;
      final tag = meta.isAi ? 'AI draft applied' : 'Draft applied';
      final detail = meta.rationale.isEmpty ? '' : ' — ${meta.rationale}';
      messenger.showSnackBar(SnackBar(content: Text('$tag$detail')));
      if (meta.warnings.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(meta.warnings.join('\n'))),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not generate a draft — try again')),
      );
    }
  }
}

/// Collects the short founder brief for AI pre-fill.
class _AiBriefSheet extends StatefulWidget {
  const _AiBriefSheet();

  @override
  State<_AiBriefSheet> createState() => _AiBriefSheetState();
}

class _AiBriefSheetState extends State<_AiBriefSheet> {
  final _schoolName = TextEditingController();
  final _lowestGrade = TextEditingController();
  final _highestGrade = TextEditingController();
  final _students = TextEditingController();
  final _teachers = TextEditingController();
  String _board = 'CBSE';
  String _schoolType = 'day_school';
  AksharaLanguage _primaryLanguage = AksharaLanguage.english;

  /// Optional modules/facilities. The value is the lowercased key the backend
  /// deterministic engine keys modules + fee categories off
  /// (see _shared/onboarding/ai_school_builder_service.ts `resolveModules`).
  static const List<({String key, String label})> _facilities = [
    (key: 'transport', label: 'Transport'),
    (key: 'hostel', label: 'Hostel'),
    (key: 'library', label: 'Library'),
    (key: 'inventory', label: 'Inventory'),
    (key: 'alumni', label: 'Alumni'),
    (key: 'hr_payroll', label: 'HR / Payroll'),
  ];
  final Set<String> _selectedModules = <String>{};

  @override
  void dispose() {
    _schoolName.dispose();
    _lowestGrade.dispose();
    _highestGrade.dispose();
    _students.dispose();
    _teachers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us about your school',
              style: context.aksharaText.titleLarge),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            controller: _schoolName,
            decoration: const InputDecoration(
              labelText: 'School name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            initialValue: _board,
            decoration: const InputDecoration(
              labelText: 'Board / curriculum',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'CBSE', child: Text('CBSE')),
              DropdownMenuItem(value: 'ICSE', child: Text('ICSE')),
              DropdownMenuItem(value: 'State Board', child: Text('State Board')),
              DropdownMenuItem(value: 'IB', child: Text('IB')),
              DropdownMenuItem(value: 'Cambridge', child: Text('Cambridge')),
            ],
            onChanged: (v) => setState(() => _board = v ?? _board),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            initialValue: _schoolType,
            decoration: const InputDecoration(
              labelText: 'School type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'day_school', child: Text('Day school')),
              DropdownMenuItem(value: 'preschool', child: Text('Preschool')),
              DropdownMenuItem(value: 'primary', child: Text('Primary')),
              DropdownMenuItem(value: 'high_school', child: Text('High school')),
              DropdownMenuItem(
                  value: 'higher_secondary', child: Text('Higher secondary')),
              DropdownMenuItem(value: 'residential', child: Text('Residential')),
            ],
            onChanged: (v) => setState(() => _schoolType = v ?? _schoolType),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lowestGrade,
                  decoration: const InputDecoration(
                    labelText: 'Lowest grade',
                    hintText: 'e.g. Nursery',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: TextField(
                  controller: _highestGrade,
                  decoration: const InputDecoration(
                    labelText: 'Highest grade',
                    hintText: 'e.g. Grade 10',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _students,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Approx. students',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: TextField(
                  controller: _teachers,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Approx. teachers',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<AksharaLanguage>(
            initialValue: _primaryLanguage,
            decoration: const InputDecoration(
              labelText: 'Primary language',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final lang in AksharaLanguage.values)
                DropdownMenuItem(
                  value: lang,
                  child: Text(lang.displayName),
                ),
            ],
            onChanged: (v) =>
                setState(() => _primaryLanguage = v ?? _primaryLanguage),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Text('Facilities & optional modules',
              style: context.aksharaText.labelLarge),
          const SizedBox(height: AksharaSpacing.s2),
          Wrap(
            spacing: AksharaSpacing.s2,
            runSpacing: AksharaSpacing.s2,
            children: [
              for (final facility in _facilities)
                FilterChip(
                  label: Text(facility.label),
                  selected: _selectedModules.contains(facility.key),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _selectedModules.add(facility.key);
                    } else {
                      _selectedModules.remove(facility.key);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: QaTestKeys.unifiedOnboardingAiPrefillApplyButton,
              onPressed: () {
                Navigator.of(context).pop(
                  SchoolBrief(
                    schoolName: _schoolName.text.trim(),
                    board: _board,
                    schoolType: _schoolType,
                    lowestGrade: _lowestGrade.text.trim(),
                    highestGrade: _highestGrade.text.trim(),
                    estimatedStudents: int.tryParse(_students.text.trim()),
                    estimatedTeachers: int.tryParse(_teachers.text.trim()),
                    languages: [_primaryLanguage.displayName],
                    interestedModules: _selectedModules.toList(growable: false),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate draft'),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s2),
        ],
      ),
    );
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
    _schoolName.addListener(_onSchoolNameChanged);
    _address.addListener(_onAddressChanged);
    _phone.addListener(_onPhoneChanged);
    _email.addListener(_onEmailChanged);
  }

  void _onSchoolNameChanged() =>
      widget.notifier.updateSchoolName(_schoolName.text);
  void _onAddressChanged() => widget.notifier.updateAddress(_address.text);
  void _onPhoneChanged() => widget.notifier.updateContactPhone(_phone.text);
  void _onEmailChanged() => widget.notifier.updateContactEmail(_email.text);

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
    // Hydration runs inside build(); detach the change listeners first so
    // seeding controller text from the (already-current) state does not call
    // back into the notifier and mutate a provider mid-build (Riverpod throws
    // "Tried to modify a provider while the widget tree was building").
    _schoolName.removeListener(_onSchoolNameChanged);
    _address.removeListener(_onAddressChanged);
    _phone.removeListener(_onPhoneChanged);
    _email.removeListener(_onEmailChanged);
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
    _schoolName.addListener(_onSchoolNameChanged);
    _address.addListener(_onAddressChanged);
    _phone.addListener(_onPhoneChanged);
    _email.addListener(_onEmailChanged);
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
