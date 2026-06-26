import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../theme/theme_extensions.dart';
import '../school_completion/school_completion_models.dart';
import '../school_completion/school_completion_providers.dart';
import 'education_models.dart';
import '../../theme/spacing.dart';

/// Batch 8c — add a question to the bank, with a real syllabus-chapter picker.
/// Feature C — pass [existing] to edit a saved question in place instead.
/// Returns the built [QuestionBankItem] on save (id '' when adding, or the
/// existing id when editing), or null on cancel.
Future<QuestionBankItem?> showAddBankItemSheet(
  BuildContext context, {
  String? initialSubject,
  QuestionBankItem? existing,
}) {
  return showModalBottomSheet<QuestionBankItem>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AddBankItemForm(initialSubject: initialSubject, existing: existing),
    ),
  );
}

class _AddBankItemForm extends ConsumerStatefulWidget {
  const _AddBankItemForm({this.initialSubject, this.existing});

  final String? initialSubject;
  final QuestionBankItem? existing;

  @override
  ConsumerState<_AddBankItemForm> createState() => _AddBankItemFormState();
}

class _AddBankItemFormState extends ConsumerState<_AddBankItemForm> {
  late final TextEditingController _subject =
      TextEditingController(text: widget.existing?.subjectName ?? widget.initialSubject ?? '');
  late final _chapter = TextEditingController(text: widget.existing?.chapter ?? '');
  late final _topic = TextEditingController(text: widget.existing?.topic ?? '');
  late final _question = TextEditingController(text: widget.existing?.questionText ?? '');
  late final _answer = TextEditingController(text: widget.existing?.answerText ?? '');
  late final _options =
      TextEditingController(text: widget.existing?.options.join(', ') ?? '');
  late final _marks = TextEditingController(text: '${widget.existing?.marks ?? 2}');

  bool get _isEdit => widget.existing != null;

  late EduQuestionType _type = widget.existing?.questionType ?? EduQuestionType.mcq;
  // The bank difficulty dropdown only offers easy/medium/hard; a paper-level
  // 'mixed' on an existing row falls back to medium so the dropdown stays valid.
  late EduDifficulty _difficulty =
      (widget.existing?.difficulty == null || widget.existing!.difficulty == EduDifficulty.mixed)
          ? EduDifficulty.medium
          : widget.existing!.difficulty;
  late EduProgramTrack _track = widget.existing?.programTrack ?? EduProgramTrack.board;
  late EduCognitiveLevel? _cognitive = widget.existing?.cognitiveLevel;
  late String? _syllabusChapterId = widget.existing?.syllabusChapterId;

  @override
  void dispose() {
    _subject.dispose();
    _chapter.dispose();
    _topic.dispose();
    _question.dispose();
    _answer.dispose();
    _options.dispose();
    _marks.dispose();
    super.dispose();
  }

  bool get _valid =>
      _subject.text.trim().isNotEmpty &&
      _chapter.text.trim().isNotEmpty &&
      _question.text.trim().isNotEmpty;

  void _save() {
    final options = _type == EduQuestionType.mcq
        ? _options.text.split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList()
        : const <String>[];
    final item = QuestionBankItem(
      id: widget.existing?.id ?? '',
      subjectName: _subject.text.trim(),
      chapter: _chapter.text.trim(),
      topic: _topic.text.trim(),
      difficulty: _difficulty,
      questionType: _type,
      marks: int.tryParse(_marks.text.trim()) ?? 1,
      questionText: _question.text.trim(),
      answerText: _answer.text.trim().isEmpty ? null : _answer.text.trim(),
      options: options,
      programTrack: _track,
      cognitiveLevel: _cognitive,
      syllabusChapterId: _syllabusChapterId,
      reviewStatus: widget.existing?.reviewStatus ?? 'approved',
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(syllabusChaptersProvider(null));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Edit bank question' : 'Add question to bank',
                  style: context.aksharaText.titleLarge),
              const SizedBox(height: 12),
              _field(_subject, 'Subject'),

              // Syllabus picker — fills the chapter and links the syllabus id.
              chapters.when(
                data: (list) => _SyllabusPicker(
                  chapters: list,
                  selectedId: _syllabusChapterId,
                  onPicked: (chapter) {
                    setState(() {
                      _syllabusChapterId = chapter?.id;
                      if (chapter != null) _chapter.text = chapter.chapterName;
                    });
                  },
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              _field(_chapter, 'Chapter', onChanged: (_) {
                // Editing the chapter by hand detaches it from a syllabus row.
                if (_syllabusChapterId != null) {
                  setState(() => _syllabusChapterId = null);
                }
              }),
              _field(_topic, 'Topic (optional)'),
              _dropdown<EduQuestionType>(
                'Question type',
                _type,
                EduQuestionType.values,
                (v) => setState(() => _type = v),
                (v) => v.name,
              ),
              _dropdown<EduDifficulty>(
                'Difficulty',
                _difficulty,
                const [EduDifficulty.easy, EduDifficulty.medium, EduDifficulty.hard],
                (v) => setState(() => _difficulty = v),
                (v) => v.name,
              ),
              _dropdown<EduProgramTrack>(
                'Program track',
                _track,
                EduProgramTrack.values,
                (v) => setState(() => _track = v),
                _trackLabel,
              ),
              _dropdown<EduCognitiveLevel?>(
                'Cognitive level (optional)',
                _cognitive,
                const [null, ...EduCognitiveLevel.values],
                (v) => setState(() => _cognitive = v),
                (v) => v?.name ?? 'none',
              ),
              _field(_marks, 'Marks', keyboardType: TextInputType.number),
              _field(_question, 'Question text', maxLines: 3),
              if (_type == EduQuestionType.mcq)
                _field(_options, 'Options (comma separated)'),
              _field(_answer, 'Answer / model answer (optional)', maxLines: 2),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: Listenable.merge([_subject, _chapter, _question]),
                builder: (context, _) => FilledButton(
                  key: QaTestKeys.educationSaveBankItemButton,
                  onPressed: _valid ? _save : null,
                  child: Text(_isEdit ? 'Save changes' : 'Save question'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T current,
    List<T> values,
    ValueChanged<T> onChanged,
    String Function(T) labelOf,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: DropdownButtonFormField<T>(
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: values
            .map((v) => DropdownMenuItem<T>(value: v, child: Text(labelOf(v))))
            .toList(),
        onChanged: (v) {
          if (v is T) onChanged(v);
        },
      ),
    );
  }
}

class _SyllabusPicker extends StatelessWidget {
  const _SyllabusPicker({
    required this.chapters,
    required this.selectedId,
    required this.onPicked,
  });

  final List<SyllabusChapter> chapters;
  final String? selectedId;
  final ValueChanged<SyllabusChapter?> onPicked;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AksharaSpacing.s2),
        child: Text(
          'No syllabus chapters found — type the chapter name below.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: DropdownButtonFormField<String?>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Pick from syllabus (optional)',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('— custom —')),
          ...chapters.map((c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text('${c.className} • ${c.chapterName}',
                    overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: (id) {
          if (id == null) {
            onPicked(null);
          } else {
            onPicked(chapters.firstWhere((c) => c.id == id));
          }
        },
      ),
    );
  }
}

String _trackLabel(EduProgramTrack track) => switch (track) {
      EduProgramTrack.board => 'Board',
      EduProgramTrack.jeeFoundation => 'JEE Foundation',
      EduProgramTrack.neetFoundation => 'NEET Foundation',
      EduProgramTrack.ntse => 'NTSE',
      EduProgramTrack.olympiad => 'Olympiad',
    };
