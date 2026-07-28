import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_text.dart';
import '../../core/reports/akshara_report_export_service.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../theme/theme_extensions.dart';
import 'onboarding_models.dart';
import '../../theme/spacing.dart';

/// First-time student data onboarding (the three paths from the plan):
///   1. STRUCTURE  → generate placeholder students from class/section sizes.
///   2. UPLOAD     → download a template, paste/parse rows, preview, commit.
///   3. ADD-ONE    → quick single-student add.
///
/// Route: `/admin/onboarding/students`.
class StudentOnboardingScreen extends ConsumerStatefulWidget {
  const StudentOnboardingScreen({super.key});

  /// Exact column order for the downloadable template (matches the plan).
  static const List<String> templateColumns = <String>[
    'Student Name',
    'Admission Number',
    'Class',
    'Section',
    'Academic Year',
    'Father / Parent Name',
    'Parent Phone',
    'Aadhaar Number',
    'Mother Name',
    'Student Phone',
    'Roll Number',
    'Date of Birth',
    'Gender',
  ];

  /// Maps each template header to the camelCase row key the backend expects.
  static const Map<String, String> columnToField = <String, String>{
    'Student Name': 'studentName',
    'Admission Number': 'admissionNumber',
    'Class': 'classLabel',
    'Section': 'sectionLabel',
    'Academic Year': 'academicYear',
    'Father / Parent Name': 'parentName',
    'Parent Phone': 'parentPhone',
    'Aadhaar Number': 'aadhaar',
    'Mother Name': 'motherName',
    'Student Phone': 'studentPhone',
    'Roll Number': 'rollNumber',
    'Date of Birth': 'dob',
    'Gender': 'gender',
  };

  static const List<String> exampleRow = <String>[
    'Asha Rao',
    'ADM-2026-0001',
    'Grade 6',
    'A',
    '2026-27',
    'Ramesh Rao',
    '9876500001',
    '', // Aadhaar
    'Lakshmi Rao',
    '', // Student phone
    '1', // Roll number
    '2014-05-12',
    'Female',
  ];

  @override
  ConsumerState<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState
    extends ConsumerState<StudentOnboardingScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bring your students'),
        bottom: TabBarSelector(
          index: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
      ),
      body: switch (_tab) {
        0 => const _StructureStep(),
        1 => const _UploadStep(),
        _ => const _AddOneStep(),
      },
    );
  }
}

/// Lightweight 3-way selector (avoids needing a TabController/SingleTickerState).
class TabBarSelector extends StatelessWidget implements PreferredSizeWidget {
  const TabBarSelector({super.key, required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _labels = ['Structure', 'Upload file', 'Add one'];

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: i == index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      fontWeight:
                          i == index ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STRUCTURE STEP — Path 2: generate placeholder students.
// ---------------------------------------------------------------------------

class _StructureRow {
  _StructureRow({
    required this.classLabel,
    required this.sectionCount,
    required this.studentsPerSection,
  });

  String classLabel;
  int sectionCount;
  int studentsPerSection;
}

class _StructureStep extends ConsumerStatefulWidget {
  const _StructureStep();

  @override
  ConsumerState<_StructureStep> createState() => _StructureStepState();
}

class _StructureStepState extends ConsumerState<_StructureStep> {
  final _yearController = TextEditingController(text: '2026-27');
  final List<_StructureRow> _rows = [
    _StructureRow(classLabel: 'Grade 6', sectionCount: 2, studentsPerSection: 30),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  int get _totalStudents => _rows.fold(
        0,
        (sum, r) => sum + (r.sectionCount * r.studentsPerSection),
      );

  List<ClassSectionStructure> _buildClasses() {
    return [
      for (final r in _rows)
        ClassSectionStructure(
          classLabel: r.classLabel,
          sections: [
            for (var i = 0; i < r.sectionCount; i++)
              SectionSize(
                // A, B, C ... by section index.
                sectionLabel: String.fromCharCode(65 + i),
                studentCount: r.studentsPerSection,
              ),
          ],
        ),
    ];
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final query = ref.read(repositoryQueryProvider);
      final job = await repo.generatePlaceholderStudents(
        query: query,
        academicYear: _yearController.text.trim(),
        classes: _buildClasses(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${job.generatedCount} placeholder students'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate placeholders: '
              '${aksharaErrorMessage(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('onboarding_structure_step'),
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        const Text(
          'Tell us your classes and how many students per section. '
          'We create editable placeholder students you can replace later.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _yearController,
          decoration: const InputDecoration(
            labelText: 'Academic Year',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _rows.length; i++) _buildClassCard(i),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _rows.add(
                _StructureRow(
                  classLabel: 'Grade ${_rows.length + 6}',
                  sectionCount: 1,
                  studentsPerSection: 30,
                ),
              )),
          icon: const Icon(Icons.add),
          label: const Text('Add class'),
        ),
        const SizedBox(height: 16),
        Text('Total placeholders: $_totalStudents',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('onboarding_generate_placeholders_btn'),
          onPressed: _busy ? null : _generate,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate placeholder students'),
        ),
      ],
    );
  }

  Widget _buildClassCard(int index) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.classLabel,
                    decoration: const InputDecoration(labelText: 'Class'),
                    onChanged: (v) => row.classLabel = v,
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _rows.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Sections',
                    value: row.sectionCount,
                    min: 1,
                    onChanged: (v) => setState(() => row.sectionCount = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    label: 'Students / section',
                    value: row.studentsPerSection,
                    min: 0,
                    onChanged: (v) =>
                        setState(() => row.studentsPerSection = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null && parsed >= min) onChanged(parsed);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// UPLOAD STEP — Path 1: template + paste/parse rows, preview, commit.
// ---------------------------------------------------------------------------

class _UploadStep extends ConsumerStatefulWidget {
  const _UploadStep();

  @override
  ConsumerState<_UploadStep> createState() => _UploadStepState();
}

class _UploadStepState extends ConsumerState<_UploadStep> {
  final _csvController = TextEditingController();
  OnboardingImportPreviewResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  String _buildTemplateCsv() {
    String escape(String v) =>
        v.contains(',') || v.contains('"') || v.contains('\n')
            ? '"${v.replaceAll('"', '""')}"'
            : v;
    final header =
        StudentOnboardingScreen.templateColumns.map(escape).join(',');
    final example = StudentOnboardingScreen.exampleRow.map(escape).join(',');
    return '$header\n$example\n';
  }

  Future<void> _downloadTemplate() async {
    final service = ref.read(aksharaReportExportServiceProvider);
    final rows = <MapEntry<String, String>>[
      MapEntry(
        StudentOnboardingScreen.templateColumns.join(' | '),
        StudentOnboardingScreen.exampleRow.join(' | '),
      ),
    ];
    try {
      await service.shareTabularCsv(
        filename: 'akshara_student_template.csv',
        reportTitle: 'Akshara Student Import Template',
        rows: rows,
      );
    } catch (_) {
      // Sharing may be unavailable in some environments; fall back to
      // pre-filling the paste box so the user always has the template.
    }
    // Always seed the paste box with the template so the columns are visible.
    _csvController.text = _buildTemplateCsv();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template ready (CSV).')),
    );
  }

  /// Parses CSV text (header row mapped to backend field names) into rows.
  List<Map<String, dynamic>> _parseCsv(String text) {
    final lines = const LineSplitter()
        .convert(text.trim())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    final headers = _splitCsvLine(lines.first);
    final fields = [
      for (final h in headers)
        StudentOnboardingScreen.columnToField[h.trim()] ?? h.trim(),
    ];
    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = _splitCsvLine(lines[i]);
      final row = <String, dynamic>{};
      for (var c = 0; c < fields.length && c < cells.length; c++) {
        final value = cells[c].trim();
        if (value.isNotEmpty) row[fields[c]] = value;
      }
      if (row.isNotEmpty) rows.add(row);
    }
    return rows;
  }

  List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    out.add(buffer.toString());
    return out;
  }

  Future<void> _uploadAndPreview() async {
    if (_busy) return;
    final rows = _parseCsv(_csvController.text);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste CSV rows (header + at least one row) first.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final query = ref.read(repositoryQueryProvider);
      final result = await repo.previewStudentImport(
        query: query,
        fileName: 'student_upload.csv',
        rows: rows,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: ${aksharaErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final result = _result;
    if (result == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final query = ref.read(repositoryQueryProvider);
      final job =
          await repo.commitImport(query: query, jobId: result.job.id);
      if (!mounted) return;
      setState(() => _result = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Committed ${job.committedRows} students.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commit failed: ${aksharaErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        const Text(
          'Download the template, fill it in Excel, then paste the rows '
          '(CSV) below and preview before committing.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('onboarding_download_template_btn'),
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download template'),
            ),
            FilledButton.icon(
              key: const Key('onboarding_upload_file_btn'),
              onPressed: _busy ? null : _uploadAndPreview,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload / preview'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _csvController,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Paste CSV (header + rows)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        if (result != null) ...[
          Text(
            'Preview: ${result.job.validRows} valid · '
            '${result.job.invalidRows} invalid · '
            '${result.job.totalRows} total',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            key: const Key('onboarding_preview_list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.preview.length,
            itemBuilder: (context, i) {
              final row = result.preview[i];
              final valid = row.status == 'valid';
              return ListTile(
                dense: true,
                leading: Icon(
                  valid ? Icons.check_circle : Icons.error_outline,
                  color: valid ? context.akshara.success : context.colors.error,
                ),
                title: Text('Row ${row.rowNumber} · ${row.status}'),
                subtitle: row.errors.isEmpty
                    ? null
                    : Text(row.errors.join('\n')),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('onboarding_commit_btn'),
            onPressed:
                _busy || result.job.validRows == 0 ? null : _commit,
            child: const Text('Commit import'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ADD-ONE STEP — Path 3: quick single-student add.
// ---------------------------------------------------------------------------

class _AddOneStep extends ConsumerStatefulWidget {
  const _AddOneStep();

  @override
  ConsumerState<_AddOneStep> createState() => _AddOneStepState();
}

class _AddOneStepState extends ConsumerState<_AddOneStep> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        const Text('Add a single student quickly.'),
        const SizedBox(height: 12),
        if (!_open)
          FilledButton.icon(
            key: const Key('onboarding_add_one_btn'),
            onPressed: () => setState(() => _open = true),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add one student'),
          )
        else
          const _AddOneForm(),
      ],
    );
  }
}

class _AddOneForm extends ConsumerStatefulWidget {
  const _AddOneForm();

  @override
  ConsumerState<_AddOneForm> createState() => _AddOneFormState();
}

class _AddOneFormState extends ConsumerState<_AddOneForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _admission = TextEditingController();
  final _classLabel = TextEditingController();
  final _section = TextEditingController();
  final _parentName = TextEditingController();
  final _parentPhone = TextEditingController();
  final _aadhaar = TextEditingController();
  final _year = TextEditingController(text: '2026-27');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _admission,
      _classLabel,
      _section,
      _parentName,
      _parentPhone,
      _aadhaar,
      _year,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final row = <String, dynamic>{
      'studentName': _name.text.trim(),
      'admissionNumber': _admission.text.trim(),
      'classLabel': _classLabel.text.trim(),
      'sectionLabel': _section.text.trim(),
      'academicYear': _year.text.trim(),
      'parentName': _parentName.text.trim(),
      'parentPhone': _parentPhone.text.trim(),
      if (_aadhaar.text.trim().isNotEmpty) 'aadhaar': _aadhaar.text.trim(),
    };
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final query = ref.read(repositoryQueryProvider);
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'add_one.csv',
        rows: [row],
      );
      if (preview.job.validRows == 0) {
        if (!mounted) return;
        final errs = preview.preview.isNotEmpty
            ? preview.preview.first.errors.join(', ')
            : 'invalid row';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add: $errs')),
        );
        return;
      }
      final job =
          await repo.commitImport(query: query, jobId: preview.job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${job.committedRows} student. '
              'Parent can now OTP-login.'),
        ),
      );
      _formKey.currentState!.reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add: ${aksharaErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        key: const Key('onboarding_add_one_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            validator: _required,
            decoration: const InputDecoration(labelText: 'Student name *'),
          ),
          TextFormField(
            controller: _admission,
            validator: _required,
            decoration: const InputDecoration(labelText: 'Admission number *'),
          ),
          TextFormField(
            controller: _classLabel,
            validator: _required,
            decoration: const InputDecoration(labelText: 'Class *'),
          ),
          TextFormField(
            controller: _section,
            validator: _required,
            decoration: const InputDecoration(labelText: 'Section *'),
          ),
          TextFormField(
            controller: _parentName,
            validator: _required,
            decoration:
                const InputDecoration(labelText: 'Father / Parent name *'),
          ),
          TextFormField(
            controller: _parentPhone,
            validator: _required,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Parent phone *'),
          ),
          TextFormField(
            controller: _aadhaar,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Aadhaar (optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save student'),
          ),
        ],
      ),
    );
  }
}
