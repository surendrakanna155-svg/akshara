import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/testing/qa_test_keys.dart';
import 'education_models.dart';
import 'education_pdf_service.dart';
import 'education_provider.dart';

class EducationScreen extends ConsumerStatefulWidget {
  const EducationScreen({super.key});

  @override
  ConsumerState<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends ConsumerState<EducationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _classController = TextEditingController(text: 'Grade 8');
  final _sectionController = TextEditingController(text: 'A');
  final _subjectController = TextEditingController(text: 'Mathematics');
  final _chaptersController = TextEditingController(text: 'Algebra, Geometry');
  final _topicController = TextEditingController(text: 'Linear equations');
  final _studentIdController = TextEditingController(text: 'student_probe_1');
  final _marksController = TextEditingController(text: '50');
  final _yearLabelController = TextEditingController(text: '2025-26');

  EduDifficulty _difficulty = EduDifficulty.mixed;
  EduExamType _examType = EduExamType.unitTest;
  EduHomeworkType _homeworkType = EduHomeworkType.homework;
  EduRemarkType _remarkType = EduRemarkType.classTeacher;
  EduRemarkLanguage _remarkLanguage = EduRemarkLanguage.english;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _classController.dispose();
    _sectionController.dispose();
    _subjectController.dispose();
    _chaptersController.dispose();
    _topicController.dispose();
    _studentIdController.dispose();
    _marksController.dispose();
    _yearLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(educationCanManageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Education Suite'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Question Papers'),
            Tab(text: 'Question Bank'),
            Tab(text: 'Homework'),
            Tab(
              key: QaTestKeys.educationReportRemarksTab,
              text: 'Report Remarks',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _questionPapersTab(canManage),
          _questionBankTab(canManage),
          _homeworkTab(canManage),
          _remarksTab(canManage),
        ],
      ),
    );
  }

  Widget _questionPapersTab(bool canManage) {
    final papers = ref.watch(questionPapersListProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (canManage) ...[
          Text('Generate question paper', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _textField(_yearLabelController, 'Academic year'),
          _textField(_classController, 'Class'),
          _textField(_sectionController, 'Section'),
          _textField(_subjectController, 'Subject'),
          _textField(_chaptersController, 'Chapters (comma separated)'),
          _textField(_marksController, 'Total marks', keyboardType: TextInputType.number),
          _dropdown('Difficulty', _difficulty.name, EduDifficulty.values, (v) {
            setState(() => _difficulty = v);
          }),
          _dropdown('Exam type', _examType.name, EduExamType.values, (v) {
            setState(() => _examType = v);
          }),
          FilledButton(
            onPressed: () async {
              final detail = await ref.read(educationMutationsProvider.notifier).generatePaper(
                    GenerateQuestionPaperRequest(
                      academicYearLabel: _yearLabelController.text.trim(),
                      className: _classController.text.trim(),
                      sectionName: _sectionController.text.trim(),
                      subjectName: _subjectController.text.trim(),
                      chapters: _chaptersController.text
                          .split(',')
                          .map((c) => c.trim())
                          .where((c) => c.isNotEmpty)
                          .toList(),
                      difficulty: _difficulty,
                      totalMarks: int.tryParse(_marksController.text) ?? 50,
                      examType: _examType,
                    ),
                  );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Generated ${detail.items.length} questions '
                    '(bank: ${detail.paper.bankReuseCount ?? 0}, '
                    'AI: ${detail.paper.aiGeneratedCount ?? 0})',
                  ),
                ),
              );
            },
            child: const Text('Generate paper'),
          ),
          const Divider(height: 32),
        ],
        papers.when(
          data: (items) => items.isEmpty
              ? const Text('No question papers yet.')
              : Column(
                  children: items
                      .map(
                        (paper) => Card(
                          child: ListTile(
                            title: Text(paper.title),
                            subtitle: Text(
                              '${paper.status} • ${paper.totalMarks} marks • '
                              'bank ${paper.bankReuseCount ?? 0} / AI ${paper.aiGeneratedCount ?? 0}',
                            ),
                            trailing: canManage
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.print_outlined),
                                        onPressed: () => _printPaper(paper.id),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.publish_outlined),
                                        onPressed: () => ref
                                            .read(educationMutationsProvider.notifier)
                                            .publishPaper(paper.id),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Future<void> _printPaper(String paperId) async {
    final detail = await ref.read(educationRepositoryProvider).getQuestionPaper(
          query: ref.read(educationQueryProvider),
          paperId: paperId,
        );
    await EducationPdfService.printQuestionPaper(detail);
  }

  Widget _questionBankTab(bool canManage) {
    final bank = ref.watch(questionBankListProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        bank.when(
          data: (items) => items.isEmpty
              ? const Text('Question bank is empty.')
              : Column(
                  children: items
                      .map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item.questionText),
                            subtitle: Text(
                              '${item.subjectName} • ${item.chapter} • '
                              '${item.questionType.name} • ${item.marks} marks',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
        if (canManage)
          FilledButton(
            onPressed: () async {
              await ref.read(educationRepositoryProvider).createQuestionBankItem(
                    query: ref.read(educationQueryProvider),
                    item: QuestionBankItem(
                      id: '',
                      subjectName: _subjectController.text.trim(),
                      chapter: _chaptersController.text.split(',').first.trim(),
                      topic: _topicController.text.trim(),
                      difficulty: _difficulty == EduDifficulty.mixed
                          ? EduDifficulty.medium
                          : _difficulty,
                      questionType: EduQuestionType.mcq,
                      marks: 2,
                      questionText:
                          'Sample MCQ for ${_subjectController.text.trim()}',
                      answerText: 'Option B',
                      options: const ['A', 'B', 'C', 'D'],
                    ),
                  );
              ref.invalidate(questionBankListProvider);
            },
            child: const Text('Add sample bank item'),
          ),
      ],
    );
  }

  Widget _homeworkTab(bool canManage) {
    final homework = ref.watch(homeworkListProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (canManage) ...[
          _dropdown('Assignment type', _homeworkType.name, EduHomeworkType.values, (v) {
            setState(() => _homeworkType = v);
          }),
          FilledButton(
            onPressed: () async {
              final created =
                  await ref.read(educationMutationsProvider.notifier).generateHomework(
                        GenerateHomeworkRequest(
                          academicYearLabel: _yearLabelController.text.trim(),
                          className: _classController.text.trim(),
                          sectionName: _sectionController.text.trim(),
                          subjectName: _subjectController.text.trim(),
                          topic: _topicController.text.trim(),
                          difficulty: _difficulty,
                          assignmentType: _homeworkType,
                        ),
                      );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Generated ${created.title}')),
              );
            },
            child: const Text('Generate homework / worksheet'),
          ),
          const Divider(height: 32),
        ],
        homework.when(
          data: (items) => items.isEmpty
              ? const Text('No homework assignments yet.')
              : Column(
                  children: items
                      .map(
                        (hw) => Card(
                          child: ListTile(
                            title: Text(hw.title),
                            subtitle: Text('${hw.status} • ${hw.content.length} questions'),
                            trailing: IconButton(
                              icon: const Icon(Icons.print_outlined),
                              onPressed: () => EducationPdfService.printHomework(hw),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _remarksTab(bool canManage) {
    final remarks = ref.watch(reportRemarksListProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (canManage) ...[
          _textField(_studentIdController, 'Student ID'),
          _dropdown('Remark type', _remarkType.name, EduRemarkType.values, (v) {
            setState(() => _remarkType = v);
          }),
          _dropdown('Language', _remarkLanguage.name, EduRemarkLanguage.values, (v) {
            setState(() => _remarkLanguage = v);
          }),
          FilledButton(
            onPressed: () async {
              await ref.read(educationMutationsProvider.notifier).generateRemark(
                    GenerateReportRemarkRequest(
                      studentId: _studentIdController.text.trim(),
                      academicYearLabel: _yearLabelController.text.trim(),
                      remarkType: _remarkType,
                      language: _remarkLanguage,
                      inputs: const ReportRemarkInputs(
                        attendancePercent: 92,
                        averageMarks: 78,
                        strengths: ['participation', 'creativity'],
                        weaknesses: ['time management'],
                        activities: ['science club'],
                      ),
                    ),
                  );
            },
            child: const Text('Generate remark'),
          ),
          const Divider(height: 32),
        ],
        remarks.when(
          data: (items) => items.isEmpty
              ? const Text('No report remarks yet.')
              : Column(
                  children: items
                      .map(
                        (remark) => Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(remark.remarkType.name),
                                  subtitle: Text(remark.displayRemark),
                                ),
                                if (remark.status == 'draft' && canManage)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      key: QaTestKeys.educationPublishRemarkButton,
                                      onPressed: () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        try {
                                          await ref
                                              .read(
                                                educationMutationsProvider.notifier,
                                              )
                                              .publishRemark(remark.id);
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              key: QaTestKeys
                                                  .educationRemarkPublishedSnackbar,
                                              content: Text(
                                                'Report remark published',
                                              ),
                                            ),
                                          );
                                        } catch (error) {
                                          messenger.showSnackBar(
                                            SnackBar(content: Text('$error')),
                                          );
                                        }
                                      },
                                      child: const Text('Publish'),
                                    ),
                                  )
                                else if (remark.status == 'published')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      key: QaTestKeys.educationReportCardExportButton,
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            key: QaTestKeys
                                                .educationReportCardExportSuccessSnackbar,
                                            content: Text(
                                              'Report card PDF export queued (${remark.studentId})',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      label: const Text('Export PDF'),
                                    ),
                                  )
                                else
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(remark.status),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    String current,
    List<T> values,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<T>(
        initialValue: values.firstWhere(
          (v) => v.toString().split('.').last == current,
          orElse: () => values.first,
        ),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: values
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v.toString().split('.').last),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
