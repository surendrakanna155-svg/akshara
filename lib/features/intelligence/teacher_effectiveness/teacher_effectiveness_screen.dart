import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';
import 'teacher_effectiveness_provider.dart';

class TeacherEffectivenessScreen extends ConsumerStatefulWidget {
  const TeacherEffectivenessScreen({super.key});

  @override
  ConsumerState<TeacherEffectivenessScreen> createState() => _TeacherEffectivenessScreenState();
}

class _TeacherEffectivenessScreenState extends ConsumerState<TeacherEffectivenessScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _studentNameController = TextEditingController(text: 'Arjun Reddy');
  final _classController = TextEditingController(text: 'Grade 8');
  final _meetingDateController = TextEditingController(text: '2026-06-20');
  final _attendanceController = TextEditingController(text: '62');
  final _marksController = TextEditingController(text: '54');
  final _homeworkController = TextEditingController(text: '55');
  final _behaviorController = TextEditingController(
    text: 'Participates actively in class discussions.',
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _studentNameController.dispose();
    _classController.dispose();
    _meetingDateController.dispose();
    _attendanceController.dispose();
    _marksController.dispose();
    _homeworkController.dispose();
    _behaviorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonScores = ref.watch(lessonEffectivenessScoresProvider);
    final topicMastery = ref.watch(topicMasteryAnalyticsProvider);
    final performance = ref.watch(teacherPerformanceInsightsProvider);
    final planning = ref.watch(teacherPlanningCenterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Effectiveness'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Lesson scores'),
            Tab(text: 'Topic mastery'),
            Tab(text: 'Performance'),
            Tab(text: 'Planning'),
            Tab(text: 'Meeting summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          lessonScores.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState(message: '$e'),
            data: (items) => ListView(
              padding: const EdgeInsets.all(16),
              children: items
                  .map(
                    (s) => ListTile(
                      title: Text('${s.topic} · ${s.className}'),
                      subtitle: Text('Engagement ${s.studentEngagementScore}% · Alignment ${s.syllabusAlignmentScore}%'),
                      trailing: Text('${s.effectivenessScore}%'),
                    ),
                  )
                  .toList(),
            ),
          ),
          topicMastery.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState(message: '$e'),
            data: (items) => ListView(
              padding: const EdgeInsets.all(16),
              children: items
                  .map(
                    (t) => ListTile(
                      title: Text(t.topicName),
                      subtitle: Text('${t.className} · ${t.lessonsCompleted} lessons'),
                      trailing: Text('${t.masteryPercent}%'),
                    ),
                  )
                  .toList(),
            ),
          ),
          performance.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState(message: '$e'),
            data: (p) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('Overall effectiveness'),
                  trailing: Text('${p.overallEffectivenessScore}/100',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: const Text('Syllabus coverage'),
                  trailing: Text('${p.syllabusCoveragePercent}%'),
                ),
                ListTile(
                  title: const Text('Avg student engagement'),
                  trailing: Text('${p.avgStudentEngagement}%'),
                ),
                const Divider(),
                const Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold)),
                ...p.strengths.map((s) => ListTile(title: Text(s))),
                const Divider(),
                const Text('Improvement areas', style: TextStyle(fontWeight: FontWeight.bold)),
                ...p.improvementAreas.map((s) => ListTile(title: Text(s))),
              ],
            ),
          ),
          planning.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState(message: '$e'),
            data: (c) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(title: const Text('Weekly focus'), subtitle: Text(c.weeklyFocus)),
                const Divider(),
                const Text('Pending topics', style: TextStyle(fontWeight: FontWeight.bold)),
                ...c.pendingTopics.map((t) => ListTile(title: Text(t))),
                const Divider(),
                const Text('Planning items', style: TextStyle(fontWeight: FontWeight.bold)),
                ...c.planningItems.map(
                  (item) => ListTile(
                    title: Text(item.action),
                    subtitle: Text('${item.category} · ${item.priority}'),
                    trailing: item.dueHint != null ? Text(item.dueHint!) : null,
                  ),
                ),
              ],
            ),
          ),
          _meetingSummaryTab(),
        ],
      ),
    );
  }

  Widget _meetingSummaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _studentNameController, decoration: const InputDecoration(labelText: 'Student name')),
        TextField(controller: _classController, decoration: const InputDecoration(labelText: 'Class')),
        TextField(controller: _meetingDateController, decoration: const InputDecoration(labelText: 'Meeting date')),
        TextField(controller: _attendanceController, decoration: const InputDecoration(labelText: 'Attendance %')),
        TextField(controller: _marksController, decoration: const InputDecoration(labelText: 'Recent marks %')),
        TextField(controller: _homeworkController, decoration: const InputDecoration(labelText: 'Homework %')),
        TextField(
          controller: _behaviorController,
          decoration: const InputDecoration(labelText: 'Behavior notes'),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _generateMeetingSummary,
          child: const Text('Generate structured summary'),
        ),
      ],
    );
  }

  Future<void> _generateMeetingSummary() async {
    final summary = await ref.read(intelligenceRepositoryProvider).generateParentMeetingSummary(
          query: ref.read(teacherEffectivenessQueryProvider),
          studentId: 'student_1',
          studentName: _studentNameController.text.trim(),
          className: _classController.text.trim(),
          meetingDate: _meetingDateController.text.trim(),
          attendancePercent: int.tryParse(_attendanceController.text.trim()),
          recentMarks: int.tryParse(_marksController.text.trim()),
          homeworkCompletionRate: int.tryParse(_homeworkController.text.trim()),
          behaviorNotes: _behaviorController.text.trim(),
        );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Summary — ${summary.studentName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.summary.opening),
              const SizedBox(height: 8),
              Text(summary.summary.academicProgress),
              const SizedBox(height: 8),
              Text(summary.summary.attendance),
              const SizedBox(height: 8),
              Text(summary.summary.homework),
              const SizedBox(height: 8),
              Text(summary.summary.behavior),
              const SizedBox(height: 8),
              Text('Action items: ${summary.summary.actionItems.join('; ')}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
