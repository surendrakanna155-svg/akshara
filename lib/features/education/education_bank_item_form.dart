import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../school_completion/school_completion_models.dart';
import '../school_completion/school_completion_providers.dart';
import 'education_models.dart';

/// Batch 8c — add a question to the bank, with a real syllabus-chapter picker.
/// Returns the built [QuestionBankItem] (id '') on save, or null on cancel.
Future<QuestionBankItem?> showAddBankItemSheet(
  BuildContext context, {
  String? initialSubject,
}) {
  return showModalBottomSheet<QuestionBankItem>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AddBankItemForm(initialSubject: initialSubject),
    ),
  );
}

class _AddBankItemForm extends ConsumerStatefulWidget {
  const _AddBankItemForm({this.initialSubject});

  final String? initialSubject;

  @override
  ConsumerState<_AddBankItemForm> createState() => _AddBankItemFormState();
}

class _AddBankItemFormState extends ConsumerState<_AddBankItemForm> {
  late final TextEditingController _subject =
      TextEditingController(text: widget.initialSubject ?? '');
  final _chapter = TextEditingController();
  final _topic = TextEditingController();
  final _question = TextEditingController();
  final _answer = TextEditingController();
  final _options = TextEditingController();
  final _marks = TextEditingController(text: '2');

  EduQuestionType _type = EduQuestionType.mcq;
  EduDifficulty _difficulty = EduDifficulty.medium;
  EduProgramTrack _track = EduProgramTrack.board;
  EduCognitiveLevel? _cognitive;
  String? _syllabusChapterId;

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
      id: '',
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
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(syllabusChaptersProvider(null));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add question to bank',
                  style: Theme.of(context).textTheme.titleLarge),
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
                  padding: EdgeInsets.symmetric(vertical: 8),
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
                  child: const Text('Save question'),
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
      padding: const EdgeInsets.only(bottom: 8),
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
      padding: const EdgeInsets.only(bottom: 8),
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
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'No syllabus chapters found — type the chapter name below.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
