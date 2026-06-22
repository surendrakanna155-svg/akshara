import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/forms/forms.dart';
import '../../shared/widgets/widgets.dart';
import 'evolution_providers.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _step = 0;
  final _schoolName = TextEditingController(text: 'Akshara International School');
  final _curriculum = TextEditingController(text: 'CBSE');
  final _studentCount = TextEditingController(text: '350');
  final _teacherCount = TextEditingController(text: '18');
  final _feeModel = TextEditingController(text: 'Term-wise tuition');

  @override
  void dispose() {
    _schoolName.dispose();
    _curriculum.dispose();
    _studentCount.dispose();
    _teacherCount.dispose();
    _feeModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(setupWizardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('School Setup Wizard')),
      body: session.when(
        data: (s) {
          final steps = <({String label, Widget content})>[
            (
              label: 'School profile',
              content: _stepContent([
                TextField(controller: _schoolName, decoration: const InputDecoration(labelText: 'School name')),
                TextField(controller: _curriculum, decoration: const InputDecoration(labelText: 'Curriculum')),
              ]),
            ),
            (
              label: 'Capacity',
              content: _stepContent([
                TextField(controller: _studentCount, decoration: const InputDecoration(labelText: 'Student count')),
                TextField(controller: _teacherCount, decoration: const InputDecoration(labelText: 'Teacher count')),
              ]),
            ),
            (
              label: 'Fee model',
              content: _stepContent([
                TextField(controller: _feeModel, decoration: const InputDecoration(labelText: 'Fee model')),
              ]),
            ),
            (
              label: 'Recommendations',
              content: _stepContent([
                Text('Academic year: ${s.recommendations['academicYear'] ?? '2026-27'}'),
                Text('Ratio: ${s.recommendations['teacherStudentRatio'] ?? '1:20'}'),
                ...s.warnings.map((w) => ListTile(leading: const Icon(Icons.warning_amber), title: Text(w))),
                ...s.missingItems.map((m) => ListTile(leading: const Icon(Icons.checklist), title: Text(m))),
              ]),
            ),
          ];
          final index = _step.clamp(0, steps.length - 1);
          final isLast = _step >= s.steps.length - 1;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AksharaMultiStepForm(
                stepLabels: [for (final step in steps) step.label],
                currentIndex: index,
                leading: _step > 0
                    ? OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      )
                    : null,
                trailing: FilledButton(
                  onPressed: () async {
                    if (_step < s.steps.length - 1) {
                      setState(() => _step++);
                    } else {
                      await ref
                          .read(evolutionRepositoryProvider)
                          .advanceSetupWizard(
                            query: ref.read(evolutionQueryProvider),
                            sessionId: s.id,
                            step: s.steps.last,
                            complete: true,
                            inputs: _inputs(),
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Setup wizard completed')),
                      );
                    }
                  },
                  child: Text(isLast ? 'Complete setup' : 'Continue'),
                ),
                child: steps[index].content,
              ),
            ),
          );
        },
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading setup wizard'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load setup wizard.',
          onRetry: () => ref.invalidate(setupWizardProvider),
        ),
      ),
    );
  }

  Map<String, dynamic> _inputs() => {
        'schoolName': _schoolName.text.trim(),
        'curriculum': _curriculum.text.trim(),
        'studentCount': int.tryParse(_studentCount.text) ?? 0,
        'teacherCount': int.tryParse(_teacherCount.text) ?? 0,
        'feeModel': _feeModel.text.trim(),
        'grades': ['Nursery', 'LKG', 'UKG', 'Grade 1', 'Grade 2', 'Grade 3'],
      };

  Widget _stepContent(List<Widget> children) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
