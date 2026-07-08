import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'parent_academic_provider.dart';

/// v13.2 — Structured parent academic report (no open AI chat).
class ParentAcademicReportScreen extends ConsumerWidget {
  const ParentAcademicReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(parentAcademicSummaryProvider);
    final report = ref.watch(parentPrintableReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Report'),
        actions: [
          report.when(
            data: (text) => IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy printable report',
              onPressed: text.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report copied to clipboard')),
                      );
                    },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ErpAsyncBody(
        state: resolveErpAsync(summary, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No academic report available.',
        onRetry: () => ref.invalidate(parentAcademicSummaryProvider),
        builder: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _section('Attendance', data.attendanceSummary),
            _section('Performance', data.performanceSummary),
            _listSection('Strengths', data.strengths),
            _listSection('Areas to improve', data.weaknesses),
            _section('Homework', data.homeworkStatus),
            _section('Exam readiness', data.examReadiness),
            _listSection('Teacher recommendations', data.teacherRecommendations),
            const SizedBox(height: 16),
            report.when(
              data: (text) => SelectableText(
                text,
                style: context.aksharaText.bodySmall,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AksharaErrorState.fromFailure(
                apiFailureMapper.fromException(e),
                onRetry: () => ref.invalidate(parentPrintableReportProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Map<String, dynamic> map) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...map.entries.map((e) => ListTile(
                  dense: true,
                  title: Text(e.key),
                  trailing: Text('${e.value}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _listSection(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ...items.map((i) => ListTile(dense: true, title: Text(i))),
          ],
        ),
      ),
    );
  }
}
