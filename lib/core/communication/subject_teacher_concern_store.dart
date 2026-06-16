import '../repositories/mock/mock_canonical_student_registry.dart';
import 'parent_communication_models.dart';

/// Escalation queue: subject teacher flags → class teacher reviews → parent message.
final class SubjectTeacherConcernStore {
  SubjectTeacherConcernStore._();

  static final SubjectTeacherConcernStore instance =
      SubjectTeacherConcernStore._();

  final List<SubjectTeacherConcern> _concerns = [];
  int _idSeq = 0;

  void reset() => _concerns.clear();

  List<SubjectTeacherConcern> allConcerns() => List.unmodifiable(_concerns);

  List<SubjectTeacherConcern> pendingForClass(String classLabel) {
    return _concerns
        .where(
          (c) =>
              c.classLabel == classLabel &&
              c.status == SubjectConcernStatus.pendingClassTeacherReview,
        )
        .toList(growable: false);
  }

  List<SubjectTeacherConcern> forStudent(String sisStudentId) {
    return _concerns
        .where((c) => c.sisStudentId == sisStudentId)
        .toList(growable: false);
  }

  SubjectTeacherConcern? byId(String concernId) {
    for (final concern in _concerns) {
      if (concern.id == concernId) return concern;
    }
    return null;
  }

  SubjectTeacherConcernFlagResult flag(SubjectTeacherConcernFlagRequest request) {
    final student = MockCanonicalStudentRegistry.byId(request.sisStudentId);
    if (student == null) {
      throw StateError('Student not found: ${request.sisStudentId}');
    }

    final concern = SubjectTeacherConcern(
      id: 'concern_${++_idSeq}',
      sisStudentId: student.sisStudentId,
      studentName: student.studentName,
      classLabel: student.classLabel,
      flaggedByTeacherId: request.flaggedByTeacherId,
      flaggedByTeacherName: request.flaggedByTeacherName,
      subject: request.subject,
      category: request.category,
      observation: request.observation.trim(),
      status: SubjectConcernStatus.pendingClassTeacherReview,
      flaggedAt: DateTime.now(),
      auditTrail: [
        '${DateTime.now().toIso8601String()} · Flagged by ${request.flaggedByTeacherName} (${request.subject})',
      ],
    );
    _concerns.insert(0, concern);
    return SubjectTeacherConcernFlagResult(concern: concern);
  }

  SubjectTeacherConcern markSent({
    required String concernId,
    required String communicationId,
    required String classTeacherName,
  }) {
    final index = _concerns.indexWhere((c) => c.id == concernId);
    if (index < 0) {
      throw StateError('Concern not found: $concernId');
    }
    final existing = _concerns[index];
    final updated = existing.copyWith(
      status: SubjectConcernStatus.sentToParent,
      reviewedAt: DateTime.now(),
      resolvedCommunicationId: communicationId,
      auditTrail: [
        ...existing.auditTrail,
        '${DateTime.now().toIso8601String()} · Reviewed and sent by $classTeacherName',
      ],
    );
    _concerns[index] = updated;
    return updated;
  }

  SubjectTeacherConcern dismiss({
    required String concernId,
    required String classTeacherName,
    String? note,
  }) {
    final index = _concerns.indexWhere((c) => c.id == concernId);
    if (index < 0) {
      throw StateError('Concern not found: $concernId');
    }
    final existing = _concerns[index];
    final updated = existing.copyWith(
      status: SubjectConcernStatus.dismissed,
      reviewedAt: DateTime.now(),
      auditTrail: [
        ...existing.auditTrail,
        '${DateTime.now().toIso8601String()} · Dismissed by $classTeacherName'
            '${note != null && note.isNotEmpty ? ': $note' : ''}',
      ],
    );
    _concerns[index] = updated;
    return updated;
  }
}
