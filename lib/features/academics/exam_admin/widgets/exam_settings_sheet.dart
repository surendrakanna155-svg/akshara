import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exams/exam_grading.dart';
import '../../../../theme/spacing.dart';
import '../exam_settings_provider.dart';

/// Opens the per-school Exam Settings panel as a bottom sheet.
Future<void> showExamSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const SingleChildScrollView(
        child: ExamSettingsPanel(),
      ),
    ),
  );
}

/// Body of the Exam Settings sheet: board grading scale, rank visibility, and
/// quick-pick term hints. Applies immediately for scale/rank; terms on Save.
class ExamSettingsPanel extends ConsumerStatefulWidget {
  const ExamSettingsPanel({super.key});

  @override
  ConsumerState<ExamSettingsPanel> createState() => _ExamSettingsPanelState();
}

class _ExamSettingsPanelState extends ConsumerState<ExamSettingsPanel> {
  late final TextEditingController _termsController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(examReportSettingsProvider);
    _termsController =
        TextEditingController(text: settings.suggestedTerms.join(', '));
  }

  @override
  void dispose() {
    _termsController.dispose();
    super.dispose();
  }

  void _saveTermsAndClose() {
    final terms = _termsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    ref.read(examReportSettingsProvider.notifier).setSuggestedTerms(terms);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(examReportSettingsProvider);
    final theme = Theme.of(context);

    return Padding(
      key: const Key('exam_settings_panel'),
      padding: const EdgeInsets.fromLTRB(
        AksharaSpacing.s4,
        AksharaSpacing.s2,
        AksharaSpacing.s4,
        AksharaSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Exam settings', style: theme.textTheme.titleLarge),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            'These apply to every exam in this school — set once for your board.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s4),

          // Grading style
          Text('Grading style', style: theme.textTheme.titleMedium),
          const SizedBox(height: AksharaSpacing.s1),
          for (final scale in ExamGradingScale.presets)
            ListTile(
              key: ValueKey('exam_scale_${scale.name}'),
              contentPadding: EdgeInsets.zero,
              selected: settings.gradingScale.name == scale.name,
              onTap: () => ref
                  .read(examReportSettingsProvider.notifier)
                  .setGradingScale(scale),
              leading: Icon(
                settings.gradingScale.name == scale.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: settings.gradingScale.name == scale.name
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(scale.name),
              subtitle:
                  Text(_exampleFor(scale), style: theme.textTheme.bodySmall),
            ),

          const Divider(height: AksharaSpacing.s6),

          // Rank visibility
          SwitchListTile(
            key: const Key('exam_settings_rank_switch'),
            contentPadding: EdgeInsets.zero,
            value: settings.showRankToParents,
            onChanged: (value) => ref
                .read(examReportSettingsProvider.notifier)
                .setShowRankToParents(value),
            title: const Text('Show rank to parents'),
            subtitle: const Text(
              'Rank is always calculated. Turn on to show it on report cards.',
            ),
          ),

          const Divider(height: AksharaSpacing.s6),

          // Term hints
          Text('Term name suggestions', style: theme.textTheme.titleMedium),
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            'Optional quick-picks when creating an exam (terms stay free text).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s2),
          TextField(
            key: const Key('exam_settings_terms_field'),
            controller: _termsController,
            decoration: const InputDecoration(
              labelText: 'Term names (comma separated)',
              hintText: 'e.g. Unit Test 1, Half-Yearly, Annual',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: AksharaSpacing.s4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('exam_settings_save_button'),
              onPressed: _saveTermsAndClose,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  String _exampleFor(ExamGradingScale scale) {
    final top = scale.bands.isNotEmpty ? scale.bands.first.label : '-';
    final bottom = scale.bands.isNotEmpty ? scale.bands.last.label : '-';
    return 'e.g. top grade "$top", lowest "$bottom"';
  }
}
