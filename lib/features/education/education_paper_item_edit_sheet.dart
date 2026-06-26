import 'package:flutter/material.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../theme/theme_extensions.dart';
import 'education_models.dart';
import '../../theme/spacing.dart';

/// Feature A — fast "fix just this one question" editor. Opens prefilled with
/// the current question and returns the edited [QuestionPaperItem] (same id /
/// number) on save, or null on cancel. Token-free; no AI involved.
Future<QuestionPaperItem?> showEditPaperItemSheet(
  BuildContext context, {
  required QuestionPaperItem item,
}) {
  return showModalBottomSheet<QuestionPaperItem>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _EditPaperItemForm(item: item),
    ),
  );
}

class _EditPaperItemForm extends StatefulWidget {
  const _EditPaperItemForm({required this.item});

  final QuestionPaperItem item;

  @override
  State<_EditPaperItemForm> createState() => _EditPaperItemFormState();
}

class _EditPaperItemFormState extends State<_EditPaperItemForm> {
  late final TextEditingController _question =
      TextEditingController(text: widget.item.questionText);
  late final TextEditingController _answer =
      TextEditingController(text: widget.item.answerText ?? '');
  late final TextEditingController _options =
      TextEditingController(text: widget.item.options.join(', '));
  late final TextEditingController _marks =
      TextEditingController(text: '${widget.item.marks}');

  late EduQuestionType _type = widget.item.questionType;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _options.dispose();
    _marks.dispose();
    super.dispose();
  }

  void _save() {
    final options = _type == EduQuestionType.mcq
        ? _options.text.split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList()
        : const <String>[];
    Navigator.of(context).pop(
      QuestionPaperItem(
        id: widget.item.id,
        questionNumber: widget.item.questionNumber,
        questionType: _type,
        marks: int.tryParse(_marks.text.trim()) ?? widget.item.marks,
        questionText: _question.text.trim(),
        answerText: _answer.text.trim().isEmpty ? null : _answer.text.trim(),
        options: options,
        source: widget.item.source,
        reviewStatus: widget.item.reviewStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit question ${widget.item.questionNumber}',
                  style: context.aksharaText.titleLarge),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                child: DropdownButtonFormField<EduQuestionType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Question type',
                    border: OutlineInputBorder(),
                  ),
                  items: EduQuestionType.values
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
              _field(_marks, 'Marks', keyboardType: TextInputType.number),
              _field(_question, 'Question text', maxLines: 3),
              if (_type == EduQuestionType.mcq)
                _field(_options, 'Options (comma separated)'),
              _field(_answer, 'Answer / model answer', maxLines: 2),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _question,
                builder: (context, _) => FilledButton(
                  key: QaTestKeys.educationSavePaperItemButton,
                  onPressed: _question.text.trim().isEmpty ? null : _save,
                  child: const Text('Save correction'),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
