import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/testing/qa_test_keys.dart';
import 'education_models.dart';

/// Batch 8c follow-up — token-free bulk import of question-bank items.
/// Teacher pastes a spreadsheet (tab) or CSV; we parse, preview, and return the
/// valid rows. The caller sends them to the de-duping import endpoint.
/// Returns the parsed valid items on "Import", or null on cancel.
Future<List<QuestionBankItem>?> showImportBankSheet(BuildContext context) {
  return showModalBottomSheet<List<QuestionBankItem>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _ImportBankForm(),
    ),
  );
}

const _templateHeader =
    'subject,chapter,topic,difficulty,type,marks,question,answer,options';
const _templateExample =
    'Mathematics,Real Numbers,HCF & LCM,easy,mcq,1,"What is the HCF of 12 and 18?",6,2|3|6|9';

class _ImportBankForm extends StatefulWidget {
  const _ImportBankForm();

  @override
  State<_ImportBankForm> createState() => _ImportBankFormState();
}

class _ImportBankFormState extends State<_ImportBankForm> {
  final _input = TextEditingController();
  List<QuestionBankItem> _valid = const [];
  int _invalidRows = 0;
  bool _parsed = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _parse() {
    final result = _parseBank(_input.text);
    setState(() {
      _valid = result.items;
      _invalidRows = result.invalidRows;
      _parsed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Import questions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Paste rows from Excel/Sheets (tab-separated) or CSV. First row '
                'must be the header below. options use | between choices.',
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SelectableText('$_templateHeader\n$_templateExample',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy template'),
                          onPressed: () => Clipboard.setData(
                            const ClipboardData(text: '$_templateHeader\n$_templateExample'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _input,
                minLines: 5,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Paste rows here',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _parse, child: const Text('Preview')),
              if (_parsed) ...[
                const SizedBox(height: 8),
                Text(
                  '${_valid.length} valid row(s)'
                  '${_invalidRows > 0 ? ' · $_invalidRows skipped (missing subject/chapter/question)' : ''}',
                  style: TextStyle(
                    color: _valid.isEmpty ? Colors.red : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ..._valid.take(3).map((q) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${q.subjectName} / ${q.chapter} · ${q.questionType.name} · '
                        '${q.marks}m · ${q.questionText}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: QaTestKeys.educationImportBankButton,
                onPressed: _parsed && _valid.isNotEmpty
                    ? () => Navigator.of(context).pop(_valid)
                    : null,
                child: Text(_parsed && _valid.isNotEmpty
                    ? 'Import ${_valid.length} question(s)'
                    : 'Import'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParseResult {
  const _ParseResult(this.items, this.invalidRows);
  final List<QuestionBankItem> items;
  final int invalidRows;
}

_ParseResult _parseBank(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return const _ParseResult([], 0);

  final delim = lines.first.contains('\t') ? '\t' : ',';
  final header = _splitLine(lines.first, delim).map((h) => h.trim().toLowerCase()).toList();
  int col(String name) => header.indexOf(name);
  final iSubject = col('subject');
  final iChapter = col('chapter');
  final iTopic = col('topic');
  final iDifficulty = col('difficulty');
  final iType = col('type');
  final iMarks = col('marks');
  final iQuestion = col('question');
  final iAnswer = col('answer');
  final iOptions = col('options');

  final items = <QuestionBankItem>[];
  var invalid = 0;
  for (final line in lines.skip(1)) {
    final f = _splitLine(line, delim);
    String at(int i) => (i >= 0 && i < f.length) ? f[i].trim() : '';
    final subject = at(iSubject);
    final chapter = at(iChapter);
    final question = at(iQuestion);
    if (subject.isEmpty || chapter.isEmpty || question.isEmpty) {
      invalid++;
      continue;
    }
    items.add(QuestionBankItem(
      id: '',
      subjectName: subject,
      chapter: chapter,
      topic: at(iTopic),
      difficulty: _difficulty(at(iDifficulty)),
      questionType: _type(at(iType)),
      marks: int.tryParse(at(iMarks)) ?? 1,
      questionText: question,
      answerText: at(iAnswer).isEmpty ? null : at(iAnswer),
      options: at(iOptions)
          .split('|')
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList(),
    ));
  }
  return _ParseResult(items, invalid);
}

/// Split one delimited line, honouring double-quoted fields (CSV).
List<String> _splitLine(String line, String delim) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        sb.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delim) {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  out.add(sb.toString());
  return out;
}

EduDifficulty _difficulty(String v) {
  final s = v.trim().toLowerCase();
  if (s.startsWith('e')) return EduDifficulty.easy;
  if (s.startsWith('h')) return EduDifficulty.hard;
  return EduDifficulty.medium;
}

EduQuestionType _type(String v) {
  final s = v.trim().toLowerCase().replaceAll(RegExp(r'[ \-]'), '_');
  switch (s) {
    case 'mcq':
    case 'multiple_choice':
      return EduQuestionType.mcq;
    case 'fill_blank':
    case 'fill_in_the_blank':
    case 'fill_in_blank':
    case 'fill':
      return EduQuestionType.fillBlank;
    case 'match':
    case 'matching':
      return EduQuestionType.match;
    case 'long_answer':
    case 'long':
    case 'essay':
      return EduQuestionType.longAnswer;
    case 'diagram':
      return EduQuestionType.diagram;
    case 'short_answer':
    case 'short':
    default:
      return EduQuestionType.shortAnswer;
  }
}
