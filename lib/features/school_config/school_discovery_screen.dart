import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/school_config/school_capability_registry.dart';
import '../../core/school_config/school_configuration_models.dart';
import '../../core/school_config/school_configuration_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../theme/spacing.dart';

/// FV-PLAT-14 — guided school discovery wizard.
class SchoolDiscoveryScreen extends ConsumerStatefulWidget {
  const SchoolDiscoveryScreen({super.key});

  @override
  ConsumerState<SchoolDiscoveryScreen> createState() =>
      _SchoolDiscoveryScreenState();
}

class _SchoolDiscoveryScreenState extends ConsumerState<SchoolDiscoveryScreen> {
  int _step = 0;
  late SchoolType _schoolType;
  late SchoolCurriculum _curriculum;
  late SchoolOperationsModel _operationsModel;
  late SchoolCapabilities _capabilities;
  int _branchCount = 1;

  @override
  void initState() {
    super.initState();
    final current = ref.read(schoolConfigurationProvider);
    _schoolType = current.schoolType;
    _curriculum = current.curriculum;
    _operationsModel = current.operationsModel;
    _capabilities = current.capabilities;
    _branchCount = current.branchCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: QaTestKeys.schoolDiscoveryScreen,
      appBar: AppBar(
        title: const Text('Smart School Configuration'),
      ),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _onContinue,
        onStepCancel: _step > 0 ? () => setState(() => _step -= 1) : null,
        steps: [
          Step(
            title: const Text('School type'),
            isActive: _step >= 0,
            content: _choiceColumn(
              SchoolType.values,
              _schoolType,
              (value) => setState(() => _schoolType = value),
              (value) => value.label,
              (value) =>
                  QaTestKeys.schoolDiscoverySchoolTypeOption(value.storageKey),
            ),
          ),
          Step(
            title: const Text('Curriculum'),
            isActive: _step >= 1,
            content: _choiceColumn(
              SchoolCurriculum.values,
              _curriculum,
              (value) => setState(() => _curriculum = value),
              (value) => value.label,
              (value) => QaTestKeys.schoolDiscoveryCurriculumOption(
                value.storageKey,
              ),
            ),
          ),
          Step(
            title: const Text('Capabilities'),
            isActive: _step >= 2,
            content: Column(
              children: [
                _capabilitySwitch(
                  'Transport',
                  _capabilities.transport,
                  (value) => setState(
                    () =>
                        _capabilities = _capabilities.copyWith(transport: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityTransport,
                ),
                _capabilitySwitch(
                  'Hostel',
                  _capabilities.hostel,
                  (value) => setState(
                    () => _capabilities = _capabilities.copyWith(hostel: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityHostel,
                ),
                _capabilitySwitch(
                  'Library',
                  _capabilities.library,
                  (value) => setState(
                    () => _capabilities = _capabilities.copyWith(library: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityLibrary,
                ),
                _capabilitySwitch(
                  'Inventory',
                  _capabilities.inventory,
                  (value) => setState(
                    () =>
                        _capabilities = _capabilities.copyWith(inventory: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityInventory,
                ),
                _capabilitySwitch(
                  'Alumni',
                  _capabilities.alumni,
                  (value) => setState(
                    () => _capabilities = _capabilities.copyWith(alumni: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityAlumni,
                ),
                _capabilitySwitch(
                  'HR Payroll',
                  _capabilities.hrPayroll,
                  (value) => setState(
                    () =>
                        _capabilities = _capabilities.copyWith(hrPayroll: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityHrPayroll,
                ),
                _capabilitySwitch(
                  'Multi-Branch',
                  _capabilities.multiBranch,
                  (value) => setState(
                    () => _capabilities =
                        _capabilities.copyWith(multiBranch: value),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityMultiBranch,
                ),
                _capabilitySwitch(
                  'Trust / Organization',
                  _capabilities.trustOrganization,
                  (value) => setState(
                    () => _capabilities = _capabilities.copyWith(
                      trustOrganization: value,
                    ),
                  ),
                  QaTestKeys.schoolDiscoveryCapabilityTrust,
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Operations model'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _choiceColumn(
                  SchoolOperationsModel.values,
                  _operationsModel,
                  (value) => setState(() => _operationsModel = value),
                  (value) => value.label,
                  (value) => QaTestKeys.schoolDiscoveryOperationsOption(
                    value.storageKey,
                  ),
                ),
                const SizedBox(height: AksharaSpacing.s4),
                Text('Branch count: $_branchCount'),
                Slider(
                  key: QaTestKeys.schoolDiscoveryBranchCountSlider,
                  value: _branchCount.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '$_branchCount',
                  onChanged: (value) =>
                      setState(() => _branchCount = value.round()),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Review'),
            isActive: _step >= 4,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('School type: ${_schoolType.label}'),
                Text('Curriculum: ${_curriculum.label}'),
                Text('Operations: ${_operationsModel.label}'),
                Text('Branches: $_branchCount'),
                const SizedBox(height: AksharaSpacing.s3),
                Text(
                  'Enabled modules: ${SchoolCapabilityRegistry.enabledModuleIds(_capabilities).join(', ')}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceColumn<T>(
    List<T> options,
    T selected,
    ValueChanged<T> onSelected,
    String Function(T) label,
    Key Function(T) keyBuilder,
  ) {
    return Column(
      children: [
        for (final option in options)
          ListTile(
            key: keyBuilder(option),
            title: Text(label(option)),
            trailing: option == selected
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.circle_outlined),
            onTap: () => onSelected(option),
          ),
      ],
    );
  }

  Widget _capabilitySwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    Key key,
  ) {
    return SwitchListTile(
      key: key,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  void _onContinue() {
    if (_step < 4) {
      setState(() => _step += 1);
      return;
    }
    _applyConfiguration();
  }

  Future<void> _applyConfiguration() async {
    final config = SchoolConfiguration(
      schoolType: _schoolType,
      curriculum: _curriculum,
      capabilities: _capabilities,
      operationsModel: _operationsModel,
      branchCount: _branchCount,
    );
    await ref.read(schoolConfigurationProvider.notifier).apply(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.schoolDiscoveryAppliedSnackbar,
        content: Text(
          'Configuration applied — ${SchoolCapabilityRegistry.enabledModuleIds(_capabilities).length} modules active',
        ),
      ),
    );
    context.pop();
  }
}
