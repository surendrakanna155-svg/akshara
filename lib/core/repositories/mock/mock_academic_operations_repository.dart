import '../../../features/sis/academic_operations/academic_operations_models.dart';
import '../../../features/sis/sis_models.dart';
import '../../../features/sis/sis_requests.dart';
import '../interfaces/academic_operations_repository.dart';
import '../repository_query.dart';
import 'mock_sis_repository.dart';

class MockAcademicOperationsRepository implements AcademicOperationsRepository {
  MockAcademicOperationsRepository({MockSisRepository? sisRepository})
      : _sisRepository = sisRepository ?? MockSisRepository();

  final MockSisRepository _sisRepository;

  static int _jobSeq = 0;
  static int _planSeq = 0;
  static final Map<String, AcademicTransitionJob> _jobs = {};
  static final Map<String, List<TransitionPreviewRow>> _planRows = {};

  @override
  Future<List<ClassMappingRule>> suggestClassMappings({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
  }) async {
    final students = await _studentsFor(query, sourceYearId: sourceYearId);
    final keys = <String>{};
    final mappings = <ClassMappingRule>[];
    for (final student in students) {
      final key = '${student.classLabel}:${student.section}';
      if (!keys.add(key)) continue;
      mappings.add(
        ClassMappingRule(
          sourceClassLabel: student.classLabel,
          sourceSection: student.section,
          targetClassLabel: _nextClass(student.classLabel),
          targetSection: student.section,
        ),
      );
    }
    mappings.sort(
      (a, b) => '${a.sourceClassLabel}${a.sourceSection}'
          .compareTo('${b.sourceClassLabel}${b.sourceSection}'),
    );
    return mappings;
  }

  @override
  Future<AcademicTransitionJob> previewYearTransition({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRule> mappings,
  }) async {
    final students = await _studentsFor(query, sourceYearId: sourceYearId);
    final previewRows = <TransitionPreviewRow>[];
    for (final student in students) {
      final mapping = mappings.firstWhere(
        (rule) =>
            rule.includeStudents &&
            rule.sourceClassLabel == student.classLabel &&
            rule.sourceSection == student.section,
        orElse: () => const ClassMappingRule(
          sourceClassLabel: '',
          sourceSection: '',
          targetClassLabel: '',
          targetSection: '',
          includeStudents: false,
        ),
      );
      if (!mapping.includeStudents) continue;
      previewRows.add(
        TransitionPreviewRow(
          studentId: student.id,
          studentName: student.studentName,
          admissionNumber: student.admissionNumber,
          fromClassLabel: student.classLabel,
          fromSection: student.section,
          toClassLabel: mapping.targetClassLabel,
          toSection: mapping.targetSection,
          reason: 'Year transition $sourceYearId → $targetYearId',
        ),
      );
    }
    final job = AcademicTransitionJob(
      id: _nextJobId(),
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
      status: AcademicTransitionJobStatus.previewed,
      createdAt: DateTime.now(),
      mappingRules: mappings,
      previewRows: previewRows,
    );
    _jobs[job.id] = job;
    return job;
  }

  @override
  Future<AcademicTransitionExecutionReport> executeYearTransition({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final job = _jobs[jobId];
    if (job == null) {
      throw StateError('Transition job not found: $jobId');
    }
    var executed = 0;
    var skipped = 0;
    for (final row in job.previewRows) {
      try {
        await _sisRepository.assignAcademicAssignment(
          query: query,
          request: AcademicAssignmentRequest(
            studentId: row.studentId,
            classLabel: row.toClassLabel,
            section: row.toSection,
            academicYear: job.targetYearId,
          ),
        );
        executed++;
      } catch (_) {
        skipped++;
      }
    }
    _jobs[jobId] = AcademicTransitionJob(
      id: job.id,
      sourceYearId: job.sourceYearId,
      targetYearId: job.targetYearId,
      status: skipped == 0
          ? AcademicTransitionJobStatus.executed
          : AcademicTransitionJobStatus.failed,
      createdAt: job.createdAt,
      mappingRules: job.mappingRules,
      previewRows: job.previewRows,
    );
    return AcademicTransitionExecutionReport(
      jobId: jobId,
      executedCount: executed,
      skippedCount: skipped,
      executedAt: DateTime.now(),
    );
  }

  @override
  Future<AcademicTransitionJob> getTransitionJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final job = _jobs[jobId];
    if (job == null) {
      throw StateError('Transition job not found: $jobId');
    }
    return job;
  }

  @override
  Future<ReshufflePlan> previewStudentReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required String strategy,
  }) async {
    final students = await _classStudents(
      query,
      classLabel: classLabel,
      academicYear: academicYear,
    );
    final sections = _sectionsFor(students);
    final ordered = [...students];
    ordered.sort((a, b) => a.admissionNumber.compareTo(b.admissionNumber));
    if (strategy == 'merit') {
      ordered.sort((a, b) => _scoreOf(b).compareTo(_scoreOf(a)));
    }
    if (strategy == 'genderParity') {
      ordered.sort((a, b) => '${a.gender}-${a.studentName}'.compareTo('${b.gender}-${b.studentName}'));
    }
    final rows = _planRowsFor(
      ordered,
      toSectionForIndex: (index) => sections[index % sections.length],
      reason: 'Reshuffle strategy: $strategy',
    );
    final id = _nextPlanId('reshuffle');
    _planRows[id] = rows;
    return ReshufflePlan(
      id: id,
      classLabel: classLabel,
      academicYear: academicYear,
      strategy: strategy,
      previewRows: rows,
    );
  }

  @override
  Future<AcademicOperationExecutionReport> executeStudentReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) {
    return _executePlan(query: query, planId: planId);
  }

  @override
  Future<SectionBalancePlan> previewSectionBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    int? targetSize,
  }) async {
    final students = await _classStudents(
      query,
      classLabel: classLabel,
      academicYear: academicYear,
    );
    final sections = _sectionsFor(students);
    final size = targetSize ?? (students.length / sections.length).ceil();
    final sorted = [...students]..sort((a, b) => _scoreOf(b).compareTo(_scoreOf(a)));
    final rows = _planRowsFor(
      sorted,
      toSectionForIndex: (index) => sections[(index ~/ size) % sections.length],
      reason: 'Section balance target: $size',
    );
    final id = _nextPlanId('section');
    _planRows[id] = rows;
    return SectionBalancePlan(
      id: id,
      classLabel: classLabel,
      academicYear: academicYear,
      targetSectionSize: size,
      previewRows: rows,
    );
  }

  @override
  Future<AcademicOperationExecutionReport> executeSectionBalance({
    required RepositoryQuery query,
    required String planId,
  }) {
    return _executePlan(query: query, planId: planId);
  }

  @override
  Future<QuarterlyReshufflePlan> previewQuarterlyReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required int quarter,
  }) async {
    final students = await _classStudents(
      query,
      classLabel: classLabel,
      academicYear: academicYear,
    );
    final sections = _sectionsFor(students);
    final ordered = [...students]..sort((a, b) => a.studentName.compareTo(b.studentName));
    final offset = quarter.clamp(1, 4) - 1;
    final rows = _planRowsFor(
      ordered,
      toSectionForIndex: (index) => sections[(index + offset) % sections.length],
      reason: 'Quarterly reshuffle Q$quarter',
    );
    final id = _nextPlanId('quarterly');
    _planRows[id] = rows;
    return QuarterlyReshufflePlan(
      id: id,
      classLabel: classLabel,
      academicYear: academicYear,
      quarter: quarter,
      previewRows: rows,
    );
  }

  @override
  Future<AcademicOperationExecutionReport> executeQuarterlyReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) {
    return _executePlan(query: query, planId: planId);
  }

  @override
  Future<PerformanceBalancePlan> previewPerformanceBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
  }) async {
    final students = await _classStudents(
      query,
      classLabel: classLabel,
      academicYear: academicYear,
    );
    final sections = _sectionsFor(students);
    final rows = _planRowsFor(
      students..sort((a, b) => _scoreOf(a).compareTo(_scoreOf(b))),
      toSectionForIndex: (index) => sections[(index * 2) % sections.length],
      reason: 'Performance balance',
    );
    final id = _nextPlanId('performance');
    _planRows[id] = rows;
    return PerformanceBalancePlan(
      id: id,
      classLabel: classLabel,
      academicYear: academicYear,
      previewRows: rows,
    );
  }

  @override
  Future<AcademicOperationExecutionReport> executePerformanceBalance({
    required RepositoryQuery query,
    required String planId,
  }) {
    return _executePlan(query: query, planId: planId);
  }

  Future<AcademicOperationExecutionReport> _executePlan({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final rows = _planRows[planId];
    if (rows == null) {
      throw StateError('Operation plan not found: $planId');
    }
    var executed = 0;
    var skipped = 0;
    final students = await _sisRepository.getStudents(query: query);
    final first = students.items.firstOrNull;
    final academicYear = first?.academicYear ?? '2026–27';
    for (final row in rows) {
      try {
        await _sisRepository.assignAcademicAssignment(
          query: query,
          request: AcademicAssignmentRequest(
            studentId: row.studentId,
            classLabel: row.toClassLabel,
            section: row.toSection,
            academicYear: academicYear,
          ),
        );
        executed++;
      } catch (_) {
        skipped++;
      }
    }
    return AcademicOperationExecutionReport(
      planId: planId,
      executedCount: executed,
      skippedCount: skipped,
      executedAt: DateTime.now(),
    );
  }

  Future<List<SisStudent>> _studentsFor(
    RepositoryQuery query, {
    required String sourceYearId,
  }) async {
    final students = await _sisRepository.getStudents(query: query);
    return students.items
        .where((student) => student.academicYear == sourceYearId)
        .toList(growable: false);
  }

  Future<List<SisStudent>> _classStudents(
    RepositoryQuery query, {
    required String classLabel,
    required String academicYear,
  }) async {
    final students = await _sisRepository.getStudents(query: query);
    return students.items
        .where(
          (student) =>
              student.classLabel == classLabel &&
              student.academicYear == academicYear &&
              student.status == SisStudentStatus.active,
        )
        .toList(growable: false);
  }

  List<String> _sectionsFor(List<SisStudent> students) {
    final sections = students.map((student) => student.section).toSet().toList();
    sections.sort();
    return sections.isEmpty ? const ['A'] : sections;
  }

  List<TransitionPreviewRow> _planRowsFor(
    List<SisStudent> students, {
    required String Function(int index) toSectionForIndex,
    required String reason,
  }) {
    final rows = <TransitionPreviewRow>[];
    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final toSection = toSectionForIndex(i);
      if (toSection == student.section) continue;
      rows.add(
        TransitionPreviewRow(
          studentId: student.id,
          studentName: student.studentName,
          admissionNumber: student.admissionNumber,
          fromClassLabel: student.classLabel,
          fromSection: student.section,
          toClassLabel: student.classLabel,
          toSection: toSection,
          reason: reason,
        ),
      );
    }
    return rows;
  }

  int _scoreOf(SisStudent student) {
    final digits = student.admissionNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return student.studentName.length * 7;
    return int.parse(digits.substring(digits.length - (digits.length > 2 ? 2 : digits.length)));
  }

  String _nextClass(String classLabel) {
    final parsed = int.tryParse(classLabel);
    if (parsed == null) return classLabel;
    return '${parsed + 1}';
  }

  String _nextJobId() => 'TRN-${++_jobSeq}';
  String _nextPlanId(String prefix) => '${prefix.toUpperCase()}-${++_planSeq}';
}
