import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import 'organization_builder_models.dart';
import 'organization_builder_mutations_provider.dart';
import 'organization_builder_providers.dart';

const _kInterviewStepCount = 7;

class OrganizationBuilderInterviewScreen extends ConsumerStatefulWidget {
  const OrganizationBuilderInterviewScreen({
    super.key,
    required this.draftId,
    required this.packId,
  });

  final String draftId;
  final String packId;

  @override
  ConsumerState<OrganizationBuilderInterviewScreen> createState() =>
      _OrganizationBuilderInterviewScreenState();
}

class _OrganizationBuilderInterviewScreenState
    extends ConsumerState<OrganizationBuilderInterviewScreen> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _scalePrimaryController = TextEditingController();
  final _scaleSecondaryController = TextEditingController();
  final _modulesController = TextEditingController();
  final _workflowsController = TextEditingController();
  final _channelsController = TextEditingController();
  final _paymentsController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _scalePrimaryController.dispose();
    _scaleSecondaryController.dispose();
    _modulesController.dispose();
    _workflowsController.dispose();
    _channelsController.dispose();
    _paymentsController.dispose();
    super.dispose();
  }

  void _hydrateFromDraft(InterviewDraft draft) {
    if (_initialized) return;
    _initialized = true;
    _step = draft.currentStep.clamp(0, _kInterviewStepCount - 1);
    _nameController.text = draft.answers['identity_name'] ?? draft.organizationName;
    _scalePrimaryController.text = draft.answers['scale_primary'] ?? '';
    _scaleSecondaryController.text = draft.answers['scale_secondary'] ?? '';
    _modulesController.text = draft.answers['modules'] ?? '';
    _workflowsController.text = draft.answers['workflows'] ?? '';
    _channelsController.text = draft.answers['channels'] ?? '';
    _paymentsController.text = draft.answers['payments'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final packsState = ref.watch(verticalPacksProvider);
    final draftState = ref.watch(interviewDraftProvider(widget.draftId));
    final saveState = ref.watch(saveInterviewStepProvider);

    final pack = packsState.maybeWhen(
      data: (packs) {
        for (final item in packs) {
          if (item.id == widget.packId) return item;
        }
        return null;
      },
      orElse: () => null,
    );

    draftState.whenData(_hydrateFromDraft);

    return Scaffold(
      key: QaTestKeys.organizationBuilderInterviewScreen,
      appBar: AppBar(
        title: Text('Interview — ${pack?.name ?? 'Organization'}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stepper(
              currentStep: _step,
              controlsBuilder: (_, __) => const SizedBox.shrink(),
              steps: List.generate(_kInterviewStepCount, (index) {
                return Step(
                  title: Text(_stepTitle(pack?.type, index)),
                  isActive: _step == index,
                  content: _stepContent(index, draftState),
                );
              }),
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
                      key: QaTestKeys.organizationBuilderInterviewBackButton,
                      onPressed: saveState.isLoading
                          ? null
                          : () => setState(() => _step -= 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step < _kInterviewStepCount - 1)
                    FilledButton(
                      key: QaTestKeys.organizationBuilderInterviewContinueButton,
                      onPressed: saveState.isLoading ? null : _continue,
                      child: saveState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                  if (_step == _kInterviewStepCount - 1)
                    FilledButton.icon(
                      key: QaTestKeys.organizationBuilderInterviewPreviewButton,
                      onPressed: saveState.isLoading ? null : _goToPreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Generate preview'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepContent(int index, AsyncValue<InterviewDraft> draftState) {
    if (index == 0) {
      return TextField(
        key: QaTestKeys.organizationBuilderInterviewNameField,
        controller: _nameController,
        decoration: InputDecoration(
          labelText: _identityLabel(widget.packId),
        ),
      );
    }
    if (index == 1) {
      return Column(
        children: [
          TextField(
            key: QaTestKeys.organizationBuilderInterviewScalePrimaryField,
            controller: _scalePrimaryController,
            decoration: InputDecoration(labelText: _scalePrimaryLabel(widget.packId)),
            keyboardType: TextInputType.number,
          ),
          TextField(
            key: QaTestKeys.organizationBuilderInterviewScaleSecondaryField,
            controller: _scaleSecondaryController,
            decoration:
                InputDecoration(labelText: _scaleSecondaryLabel(widget.packId)),
            keyboardType: TextInputType.number,
          ),
        ],
      );
    }
    if (index == 2) {
      return TextField(
        key: QaTestKeys.organizationBuilderInterviewModulesField,
        controller: _modulesController,
        decoration: const InputDecoration(
          labelText: 'Enabled modules (comma-separated)',
        ),
        maxLines: 2,
      );
    }
    if (index == 3) {
      return TextField(
        key: QaTestKeys.organizationBuilderInterviewWorkflowsField,
        controller: _workflowsController,
        decoration: const InputDecoration(
          labelText: 'Key workflows',
        ),
        maxLines: 2,
      );
    }
    if (index == 4) {
      return TextField(
        key: QaTestKeys.organizationBuilderInterviewChannelsField,
        controller: _channelsController,
        decoration: const InputDecoration(
          labelText: 'Notification channels (WA, SMS, email)',
        ),
      );
    }
    if (index == 5) {
      return TextField(
        key: QaTestKeys.organizationBuilderInterviewPaymentsField,
        controller: _paymentsController,
        decoration: const InputDecoration(
          labelText: 'Payment configuration',
        ),
      );
    }

    return draftState.when(
      loading: () => const AksharaLoadingState(),
      error: (error, _) => Text('Unable to load draft: $error'),
      data: (draft) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Organization: ${draft.organizationName}'),
          Text('Completed steps: ${draft.currentStep}/$_kInterviewStepCount'),
          if (draft.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'AI Recommendations',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final rec in draft.recommendations.take(3))
              ListTile(
                key: QaTestKeys.organizationBuilderRecommendation(rec.id),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(rec.title),
                subtitle: Text(rec.detail),
              ),
          ],
        ],
      ),
    );
  }

  String _stepTitle(VerticalPackType? type, int index) {
    return switch (index) {
      0 => 'Identity',
      1 => 'Scale',
      2 => 'Modules',
      3 => 'Workflows',
      4 => 'Channels',
      5 => 'Payments',
      _ => 'Review',
    };
  }

  String _identityLabel(String packId) {
    return switch (packId) {
      'pack_salon' => 'Salon brand name',
      'pack_hospital' => 'Hospital name',
      'pack_restaurant' => 'Restaurant name',
      _ => 'School name',
    };
  }

  String _scalePrimaryLabel(String packId) {
    return switch (packId) {
      'pack_salon' => 'Stylists',
      'pack_hospital' => 'Beds',
      'pack_restaurant' => 'Tables',
      _ => 'Students',
    };
  }

  String _scaleSecondaryLabel(String packId) {
    return switch (packId) {
      'pack_salon' => 'Chairs',
      'pack_hospital' => 'Doctors',
      'pack_restaurant' => 'Kitchen stations',
      _ => 'Teachers',
    };
  }

  Map<String, String> _answersForStep(int step) {
    return switch (step) {
      0 => {
          'pack_id': widget.packId,
          'identity_name': _nameController.text.trim(),
        },
      1 => {
          'scale_primary': _scalePrimaryController.text.trim(),
          'scale_secondary': _scaleSecondaryController.text.trim(),
        },
      2 => {'modules': _modulesController.text.trim()},
      3 => {'workflows': _workflowsController.text.trim()},
      4 => {'channels': _channelsController.text.trim()},
      5 => {'payments': _paymentsController.text.trim()},
      _ => {'review': 'confirmed'},
    };
  }

  Future<void> _continue() async {
    final result = await ref.read(saveInterviewStepProvider.notifier).execute(
          draftId: widget.draftId,
          stepIndex: _step,
          answers: _answersForStep(_step),
        );
    if (result == null || !mounted) return;
    setState(() => _step = (_step + 1).clamp(0, _kInterviewStepCount - 1));
  }

  Future<void> _goToPreview() async {
    await ref.read(saveInterviewStepProvider.notifier).execute(
          draftId: widget.draftId,
          stepIndex: _step,
          answers: _answersForStep(_step),
        );
    final preview = await ref
        .read(generatePreviewProvider.notifier)
        .execute(draftId: widget.draftId);
    if (preview == null || !mounted) return;
    context.push(
      '${RouteNames.organizationBuilderPreview}?draftId=${widget.draftId}',
    );
  }
}
