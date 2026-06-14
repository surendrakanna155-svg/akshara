import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../admin/admin_layout.dart';
import '../../admissions/admissions_models.dart';
import '../integration/sis_admissions_integration_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../widgets/sis_enrollment_queue.dart';
import '../widgets/sis_module_scaffold.dart';

/// SIS-05 — Admissions Conversion.
class SisAdmissionsConversionScreen extends ConsumerStatefulWidget {
  const SisAdmissionsConversionScreen({super.key});

  @override
  ConsumerState<SisAdmissionsConversionScreen> createState() =>
      _SisAdmissionsConversionScreenState();
}

class _SisAdmissionsConversionScreenState
    extends ConsumerState<SisAdmissionsConversionScreen> {
  String? _previewClass;
  String? _previewSection;
  String? _previewYear;

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(sisAdmissionsConversionViewStateProvider);
    final queue = ref.watch(sisEnrollmentQueueProvider);
    final pending = ref.watch(sisPendingEnrollmentsProvider);
    final selectedId = ref.watch(sisSelectedEnrollmentIdProvider);
    final isMobile = AdminLayout.isMobile(context);

    SisEnrollmentQueueItem? selected;
    for (final item in queue) {
      if (item.enrollment.id == selectedId) {
        selected = item;
        break;
      }
    }
    selected ??= pending.isEmpty ? null : pending.first;

    if (selected != null && _previewClass == null) {
      _previewClass = selected.enrollment.seekingClass;
      _previewSection = selected.enrollment.section;
      _previewYear = selected.enrollment.academicYear;
    }

    return SisModuleScaffold(
      screen: SisScreen.admissionsConversion,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(title: 'Admissions conversion'),
          Text(
            'Convert AD-05 enrollment records into SIS student profiles.',
            style: context.aksharaText.bodyMedium,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SisAsyncBody<SisAdmissionsConversionData>(
            state: viewState,
            loadingLabel: 'Loading admissions conversion queue',
            emptyMessage: 'No enrollment records available for conversion.',
            emptyIcon: Icons.swap_horiz_outlined,
            onRetry: () =>
                retrySisFuture(ref, sisAdmissionsConversionFutureProvider),
            builder: (_) {
              if (isMobile) {
                return Column(
                  children: [
                    SisEnrollmentQueue(
                      items: queue,
                      onConvert: (item) {
                        ref
                            .read(sisSelectedEnrollmentIdProvider.notifier)
                            .state = item.enrollment.id;
                        setState(() {
                          _previewClass = item.enrollment.seekingClass;
                          _previewSection = item.enrollment.section;
                          _previewYear = item.enrollment.academicYear;
                        });
                      },
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: AksharaSpacing.s4),
                      _ConversionPanel(
                        item: selected,
                        previewClass:
                            _previewClass ?? selected.enrollment.seekingClass,
                        previewSection:
                            _previewSection ?? selected.enrollment.section,
                        previewYear:
                            _previewYear ?? selected.enrollment.academicYear,
                        onClassChanged: (v) => setState(() {
                          _previewClass = v;
                          final filtered = ref.read(
                            sectionOptionsForClassProvider(v),
                          );
                          if (filtered.isNotEmpty &&
                              !filtered.contains(_previewSection)) {
                            _previewSection = filtered.first;
                          }
                        }),
                        onSectionChanged: (v) =>
                            setState(() => _previewSection = v),
                        onYearChanged: (v) => setState(() => _previewYear = v),
                        onConvert: () => _completeConversion(selected!),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SisEnrollmentQueue(
                      items: queue,
                      onConvert: (item) {
                        ref
                            .read(sisSelectedEnrollmentIdProvider.notifier)
                            .state = item.enrollment.id;
                        setState(() {
                          _previewClass = item.enrollment.seekingClass;
                          _previewSection = item.enrollment.section;
                          _previewYear = item.enrollment.academicYear;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s6),
                  Expanded(
                    flex: 3,
                    child: selected == null
                        ? const AksharaEmptyState(
                            message: 'Select an enrollment to convert.',
                            icon: Icons.person_add_outlined,
                          )
                        : _ConversionPanel(
                            item: selected,
                            previewClass:
                                _previewClass ?? selected.enrollment.seekingClass,
                            previewSection:
                                _previewSection ?? selected.enrollment.section,
                            previewYear:
                                _previewYear ?? selected.enrollment.academicYear,
                            onClassChanged: (v) => setState(() {
                              _previewClass = v;
                              final filtered = ref.read(
                                sectionOptionsForClassProvider(v),
                              );
                              if (filtered.isNotEmpty &&
                                  !filtered.contains(_previewSection)) {
                                _previewSection = filtered.first;
                              }
                            }),
                            onSectionChanged: (v) =>
                                setState(() => _previewSection = v),
                            onYearChanged: (v) =>
                                setState(() => _previewYear = v),
                            onConvert: () => _completeConversion(selected!),
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _completeConversion(SisEnrollmentQueueItem item) async {
    if (item.effectiveStatus == EnrollmentConversionStatus.converted) return;

    final admissionNumber = generateAdmissionNumber(item.enrollment.id);
    final studentId = generateSisStudentId(item.enrollment.id);
    final preview = SisConversionPreview(
      studentId: studentId,
      admissionNumber: admissionNumber,
      studentName: item.enrollment.studentName,
      classLabel: _previewClass ?? item.enrollment.seekingClass,
      section: _previewSection ?? item.enrollment.section,
      academicYear: _previewYear ?? item.enrollment.academicYear,
    );

    try {
      final result = await completeSisEnrollmentConversion(
        ref,
        enrollmentId: item.enrollment.id,
        preview: preview,
      );

      if (!mounted || result == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.sisConversionSuccessSnackbar,
          content: Text(
            'Created SIS profile ${result.studentId} (${result.admissionNumber})',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _ConversionPanel extends ConsumerWidget {
  const _ConversionPanel({
    required this.item,
    required this.previewClass,
    required this.previewSection,
    required this.previewYear,
    required this.onClassChanged,
    required this.onSectionChanged,
    required this.onYearChanged,
    required this.onConvert,
  });

  final SisEnrollmentQueueItem item;
  final String previewClass;
  final String previewSection;
  final String previewYear;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<String> onYearChanged;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classOptionsProvider);
    final sections =
        ref.watch(sectionOptionsForClassProvider(previewClass));
    final years = ref.watch(yearOptionsProvider);
    final enrollment = item.enrollment;
    final isConverted =
        item.effectiveStatus == EnrollmentConversionStatus.converted;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(enrollment.studentName, style: context.aksharaText.titleMedium),
            Text(
              '${enrollment.applicationId} · Submitted ${enrollment.submittedAt}',
              style: context.aksharaText.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s6),
            if (isConverted) ...[
              const AksharaSectionHeader(title: 'SIS student profile created'),
              const SizedBox(height: AksharaSpacing.s3),
              _PreviewCard(
                studentId: enrollment.previewStudentId ?? '—',
                admissionNumber:
                    enrollment.generatedAdmissionNumber ?? '—',
                classLabel: enrollment.seekingClass,
                section: enrollment.section,
              ),
            ] else ...[
              Material(
                child: DropdownMenu<String>(
                  key: ValueKey(previewClass),
                  initialSelection: previewClass,
                  label: const Text('Preview class'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    for (final c in classes)
                      DropdownMenuEntry(value: c, label: c),
                  ],
                  onSelected: (v) {
                    if (v != null) onClassChanged(v);
                  },
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              Material(
                child: DropdownMenu<String>(
                  key: ValueKey(previewSection),
                  initialSelection: previewSection,
                  label: const Text('Preview section'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    for (final s in sections)
                      DropdownMenuEntry(value: s, label: s),
                  ],
                  onSelected: (v) {
                    if (v != null) onSectionChanged(v);
                  },
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              Material(
                child: DropdownMenu<String>(
                  key: ValueKey(previewYear),
                  initialSelection: previewYear,
                  label: const Text('Academic year'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    for (final y in years)
                      DropdownMenuEntry(value: y, label: y),
                  ],
                  onSelected: (v) {
                    if (v != null) onYearChanged(v);
                  },
                ),
              ),
              const SizedBox(height: AksharaSpacing.s6),
              AksharaManageAction(
                permission: Permission.manageSis,
                child: FilledButton.icon(
                  key: QaTestKeys.sisConvertEnrollmentButton,
                  onPressed: onConvert,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Convert to SIS student'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.studentId,
    required this.admissionNumber,
    required this.classLabel,
    required this.section,
  });

  final String studentId;
  final String admissionNumber;
  final String classLabel;
  final String section;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SIS student preview $studentId',
      child: Container(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student ID: $studentId', style: context.aksharaText.titleSmall),
            Text('Admission: $admissionNumber'),
            Text('Class: $classLabel-$section'),
          ],
        ),
      ),
    );
  }
}
