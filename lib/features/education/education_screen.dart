import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import '../../theme/theme_extensions.dart';
import 'education_bank_import_sheet.dart';
import 'education_bank_item_form.dart';
import 'education_models.dart';
import 'education_pdf_service.dart';
import 'education_provider.dart';
import 'education_question_paper_detail_screen.dart';
import '../../theme/spacing.dart';
import '../../core/errors/error_text.dart';

class EducationScreen extends ConsumerStatefulWidget {
  const EducationScreen({super.key});

  @override
  ConsumerState<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends ConsumerState<EducationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _showExamAdminBanner = true;

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
  EduProgramTrack _programTrack = EduProgramTrack.board;
  bool _allowAiGapFill = true;
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showExamAdminBanner)
            MaterialBanner(
              content: const Text(
                'Question papers and worksheets live here. Exam scheduling, marks entry, '
                'and result publication are managed in ERP Exam Administration (School Completion).',
              ),
              leading: const Icon(Icons.info_outline),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _showExamAdminBanner = false),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _questionPapersTab(canManage),
                _questionBankTab(canManage),
                _homeworkTab(canManage),
                _remarksTab(canManage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionPapersTab(bool canManage) {
    final papers = ref.watch(questionPapersListProvider);
    final lastGenerated = ref.watch(lastGeneratedPaperProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (canManage) ...[
          Text('Generate question paper', style: context.aksharaText.titleMedium),
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
          _dropdown('Program track', _programTrack.name, EduProgramTrack.values, (v) {
            setState(() => _programTrack = v);
          }),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow AI gap-fill'),
            subtitle: const Text(
              'Bank-first. Slots the bank cannot cover are offered to AI as '
              'moderation candidates (never auto-published).',
            ),
            value: _allowAiGapFill,
            onChanged: (v) => setState(() => _allowAiGapFill = v),
          ),
          FilledButton(
            onPressed: () => _generatePaper(),
            child: const Text('Generate paper'),
          ),
          if (lastGenerated != null) ...[
            const SizedBox(height: 12),
            _generationResultBanner(lastGenerated),
          ],
          const Divider(height: 32),
        ],
        papers.when(
          data: (items) => items.isEmpty
              ? const AksharaEmptyState(message: 'No question papers yet.')
              : Column(
                  children: items.map((paper) => _paperCard(paper, canManage)).toList(),
                ),
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading papers'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(questionPapersListProvider),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePaper() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
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
              programTrack: _programTrack,
              allowAiGapFill: _allowAiGapFill,
            ),
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Generated ${detail.items.length} questions '
            '(bank: ${detail.paper.bankReuseCount ?? 0}, '
            'AI candidates: ${detail.aiCandidateCount})',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }

  Widget _generationResultBanner(QuestionPaperDetail detail) {
    final hasIssues = detail.unfilledGapCount > 0 || detail.aiCandidateCount > 0;
    final color = detail.unfilledGapCount > 0
        ? context.akshara.warning
        : (detail.aiCandidateCount > 0 ? Colors.deepPurple : context.akshara.success);
    final lines = <String>[
      if (detail.unfilledMarks > 0)
        '${detail.unfilledMarks} marks unfilled across ${detail.unfilledGapCount} slot(s) — '
            'add bank questions or enable AI gap-fill.',
      if (detail.aiCandidateCount > 0)
        '${detail.aiCandidateCount} AI candidate(s) need moderation before publishing.',
      if (!hasIssues) 'Fully covered by the bank — ready to submit.',
    ];
    return Container(
      key: detail.unfilledGapCount > 0 ? QaTestKeys.educationUnfilledMarksBanner : null,
      padding: const EdgeInsets.all(AksharaSpacing.s3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.paper.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $l'),
              )),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () => _openPaper(detail.paper.id),
              child: const Text('Review & moderate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paperCard(QuestionPaperSummary paper, bool canManage) {
    return Card(
      child: ListTile(
        title: Text(paper.title),
        subtitle: Text(
          '${_reviewStatusLabel(paper.reviewStatus)} • ${paper.totalMarks} marks • '
          'bank ${paper.bankReuseCount ?? 0} / AI ${paper.aiGeneratedCount ?? 0}',
        ),
        trailing: canManage
            ? IconButton(
                tooltip: 'Print',
                icon: const Icon(Icons.print_outlined),
                onPressed: () => _printPaper(paper.id),
              )
            : null,
        onTap: () => _openPaper(paper.id),
      ),
    );
  }

  void _openPaper(String paperId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionPaperDetailScreen(paperId: paperId),
      ),
    );
  }

  String _reviewStatusLabel(EduPaperReviewStatus status) => switch (status) {
        EduPaperReviewStatus.draft => 'Draft',
        EduPaperReviewStatus.submitted => 'Submitted',
        EduPaperReviewStatus.changesRequested => 'Changes requested',
        EduPaperReviewStatus.approved => 'Approved',
        EduPaperReviewStatus.published => 'Published',
        EduPaperReviewStatus.archived => 'Archived',
      };

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
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        bank.when(
          data: (items) => items.isEmpty
              ? const AksharaEmptyState(message: 'Question bank is empty.')
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
                            trailing: canManage
                                ? IconButton(
                                    key: QaTestKeys.educationEditBankItemButton(item.id),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit question',
                                    onPressed: () => _editBankItem(item),
                                  )
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading bank'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(questionBankListProvider),
          ),
        ),
        if (canManage)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: QaTestKeys.educationAddBankItemButton,
                  icon: const Icon(Icons.add),
                  onPressed: () => _addBankItem(),
                  label: const Text('Add question'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: QaTestKeys.educationImportBankButton,
                  icon: const Icon(Icons.upload_file_outlined),
                  onPressed: () => _importBank(),
                  label: const Text('Import (CSV)'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _importBank() async {
    final messenger = ScaffoldMessenger.of(context);
    final items = await showImportBankSheet(context);
    if (items == null || items.isEmpty) return;
    try {
      final result = await ref.read(educationRepositoryProvider).importQuestionBank(
            query: ref.read(educationQueryProvider),
            items: items,
          );
      ref.invalidate(questionBankListProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.imported} question(s)'
            '${result.skippedDuplicates > 0 ? ' • ${result.skippedDuplicates} duplicate(s) skipped' : ''}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }

  Future<void> _addBankItem() async {
    final messenger = ScaffoldMessenger.of(context);
    final item = await showAddBankItemSheet(
      context,
      initialSubject: _subjectController.text.trim(),
    );
    if (item == null) return;
    try {
      await ref.read(educationRepositoryProvider).createQuestionBankItem(
            query: ref.read(educationQueryProvider),
            item: item,
          );
      ref.invalidate(questionBankListProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Question added to bank')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }

  Future<void> _editBankItem(QuestionBankItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final edited = await showAddBankItemSheet(context, existing: item);
    if (edited == null) return;
    try {
      await ref.read(educationMutationsProvider.notifier).updateBankItem(edited);
      messenger.showSnackBar(
        const SnackBar(content: Text('Question updated')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(aksharaErrorMessage(error))));
    }
  }

  Widget _homeworkTab(bool canManage) {
    final homework = ref.watch(homeworkListProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
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
              ? const AksharaEmptyState(message: 'No homework assignments yet.')
              : Column(
                  children: items
                      .map(
                        (hw) => Card(
                          child: ListTile(
                            title: Text(hw.title),
                            subtitle: Text('${hw.status} • ${hw.content.length} questions'),
                            trailing: IconButton(
                              tooltip: 'Print',
                              icon: const Icon(Icons.print_outlined),
                              onPressed: () => EducationPdfService.printHomework(hw),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading homework'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(homeworkListProvider),
          ),
        ),
      ],
    );
  }

  Widget _remarksTab(bool canManage) {
    final remarks = ref.watch(reportRemarksListProvider);
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
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
              ? const AksharaEmptyState(message: 'No report remarks yet.')
              : Column(
                  children: items
                      .map(
                        (remark) => Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AksharaSpacing.s2,
                              vertical: AksharaSpacing.s1,
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
                                            SnackBar(content: Text(aksharaErrorMessage(error))),
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
                                        EducationPdfService.printReportCardRemark(
                                          remark,
                                        ).catchError((_) {});
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            key: QaTestKeys
                                                .educationReportCardExportSuccessSnackbar,
                                            content: Text(
                                              'Report card PDF ready (${remark.studentId})',
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
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading remarks'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(reportRemarksListProvider),
          ),
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
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
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
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
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
