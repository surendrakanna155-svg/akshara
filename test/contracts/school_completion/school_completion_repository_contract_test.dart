import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/school_completion/school_completion_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockSchoolCompletionRepository();

  group('School Completion contract parity', () {
    test('subjects catalog supports create and list', () async {
      final initial = await repo.listSubjects(query: query);
      expect(initial.length, greaterThanOrEqualTo(3));

      final created = await repo.createSubject(
        query: query,
        subjectCode: 'HIN',
        subjectName: 'Hindi',
      );
      expect(created.subjectCode, 'HIN');

      final updated = await repo.listSubjects(query: query);
      expect(updated.any((s) => s.id == created.id), isTrue);
    });

    test('lesson logs round-trip', () async {
      final created = await repo.createLessonLog(
        query: query,
        className: 'Grade 7',
        topic: 'Algebra intro',
      );
      final logs =
          await repo.listLessonLogs(query: query, className: 'Grade 7');
      expect(logs.any((l) => l.id == created.id), isTrue);
    });

    test('timetable automation uses subject catalog', () async {
      final result = await repo.automateTimetables(
        query: query,
        academicYearId: 'year_1',
      );
      expect(result.timetablesCreated, greaterThan(0));
      expect(result.subjectsUsed, isNotEmpty);
    });

    test('branding save and load', () async {
      const branding = SchoolBranding(
        displayName: 'Test School',
        tagline: 'Excellence',
        primaryColor: '#112233',
        secondaryColor: '#AABBCC',
      );
      await repo.saveBranding(query: query, branding: branding);
      final loaded = await repo.getBranding(query: query);
      expect(loaded.displayName, 'Test School');
    });

    test('whatsapp provider test stub succeeds', () async {
      await repo.saveWhatsAppProvider(
        query: query,
        config: const WhatsAppProviderConfig(provider: 'stub', isActive: true),
      );
      final result = await repo.testWhatsAppProvider(
        query: query,
        toPhone: '+919999999999',
      );
      expect(result.success, isTrue);
    });

    test('class subject assignment prevents duplicates', () async {
      await repo.createClassSubjectAssignment(
        query: query,
        academicYearId: 'year_1',
        classId: 'class_1',
        subjectId: 'sub_1',
      );
      expect(
        () => repo.createClassSubjectAssignment(
          query: query,
          academicYearId: 'year_1',
          classId: 'class_1',
          subjectId: 'sub_1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('subject workload calculation aggregates teacher periods', () async {
      await repo.createTeacherSubjectAssignment(
        query: query,
        academicYearId: 'year_1',
        teacherUserId: 'teacher_1',
        subjectId: 'sub_1',
        periodsPerWeek: 20,
      );
      await repo.createTeacherSubjectAssignment(
        query: query,
        academicYearId: 'year_1',
        teacherUserId: 'teacher_1',
        subjectId: 'sub_1',
        classId: 'class_2',
        periodsPerWeek: 10,
      );
      final workload = await repo.getSubjectWorkload(query: query);
      expect(workload.single.totalPeriods, 30);
      expect(workload.single.isOverloaded, isTrue);
    });

    test('lesson analytics and pilot dashboard return data', () async {
      final teacher = await repo.getTeacherLessonAnalytics(query: query);
      expect(teacher.coveragePercent, greaterThanOrEqualTo(0));

      final principal = await repo.getPrincipalLessonAnalytics(query: query);
      expect(principal, isNotEmpty);

      final pilot = await repo.getPilotDashboard(query: query);
      expect(pilot.pilotScore, greaterThanOrEqualTo(0));
    });

    test('timetable optimization returns quality score', () async {
      final result = await repo.getTimetableOptimization(
        query: query,
        academicYearId: 'year_1',
      );
      expect(result.qualityScore, greaterThan(0));
      expect(
        result.recommendations.any(
          (recommendation) =>
              recommendation.recommendationId != null &&
              !recommendation.readOnly,
        ),
        isTrue,
      );
    });

    test('apply timetable optimization persists optimization updates',
        () async {
      final before = await repo.getTimetableOptimization(
        query: query,
        academicYearId: 'year_1',
      );
      final actionable = before.recommendations.firstWhere(
        (recommendation) =>
            recommendation.recommendationId != null && !recommendation.readOnly,
      );
      final applied = await repo.applyTimetableOptimization(
        query: query,
        academicYearId: 'year_1',
        recommendationIds: [actionable.recommendationId!],
      );
      expect(applied.appliedCount, 1);
      expect(applied.appliedRecommendationIds,
          contains(actionable.recommendationId));
      expect(applied.updatedConflictCount, lessThan(before.conflictCount));
      expect(applied.updatedQualityScore, greaterThan(before.qualityScore));

      final after = await repo.getTimetableOptimization(
        query: query,
        academicYearId: 'year_1',
      );
      final updatedRecommendation = after.recommendations.firstWhere(
        (recommendation) =>
            recommendation.recommendationId == actionable.recommendationId,
      );
      expect(updatedRecommendation.readOnly, isTrue);
    });

    test('substitute coverage and assignment flow returns timetable update',
        () async {
      final coverage = await repo.getSubstituteCoverage(
        query: query,
        academicYearId: 'year_1',
        dayOfWeek: 'Monday',
      );
      expect(coverage.openSlots, isNotEmpty);
      expect(coverage.candidates, isNotEmpty);

      final assignment = await repo.assignSubstitute(
        query: query,
        request: AssignSubstituteRequest(
          slotId: coverage.openSlots.first.slotId,
          substituteTeacherId: coverage.candidates.first.teacherId,
          notifySubstituteTeacher: true,
          notifyClassIncharge: true,
          notifyStudents: false,
        ),
      );
      expect(assignment.timetableUpdated, isTrue);
      expect(assignment.notifiedAudience, isNotEmpty);
    });

    test('teacher reassignment options and execute flow return update summary',
        () async {
      final options = await repo.getTeacherReassignmentOptions(
        query: query,
        academicYearId: 'year_1',
      );
      expect(options.slots, isNotEmpty);
      expect(options.candidates, isNotEmpty);

      final result = await repo.reassignTeacher(
        query: query,
        request: ReassignTeacherRequest(
          academicYearId: 'year_1',
          sourceTeacherId: options.sourceTeacherId,
          targetTeacherId: options.candidates.first.teacherId,
          slotIds: [options.slots.first.slotId],
          notifySourceTeacher: true,
          notifyTargetTeacher: true,
          notifyStudents: false,
        ),
      );
      expect(result.updatedSlotIds, isNotEmpty);
      expect(result.sourceTeacherId, options.sourceTeacherId);
      expect(result.targetTeacherId, options.candidates.first.teacherId);
    });

    test('delivery analytics returns channel breakdown', () async {
      final analytics = await repo.getDeliveryAnalytics(query: query);
      expect(analytics.deliveryRate, greaterThan(0));
      expect(analytics.byChannel, isNotEmpty);
    });

    test('communication analytics summary returns all sections', () async {
      final analytics = await repo.getCommunicationAnalytics(query: query);
      expect(analytics.campaigns.totalCampaigns, greaterThan(0));
      expect(analytics.delivery.deliveryRate, greaterThan(0));
      expect(
          analytics.effectiveness.effectivenessScore, greaterThanOrEqualTo(0));
      expect(analytics.parentEngagement.averageEngagementScore,
          greaterThanOrEqualTo(0));
      expect(analytics.parentAdoption.adoptionRate, greaterThanOrEqualTo(0));
    });

    test('phase 10 syllabus and academic progress return data', () async {
      final templates = await repo.listSubjectTemplates(query: query);
      expect(templates, isNotEmpty);

      final generated = await repo.generateSyllabus(
        query: query,
        academicYearId: 'year_1',
        className: 'Grade 7',
        subjectId: 'sub_1',
        subjectName: 'Mathematics',
        gradeLabel: 'Grade 7',
      );
      expect(generated.chaptersCreated, greaterThan(0));

      final teacher = await repo.getTeacherProgress(query: query);
      expect(teacher.coveragePercent, greaterThanOrEqualTo(0));

      final principal = await repo.getPrincipalAcademicProgress(query: query);
      expect(principal.overallCoveragePercent, greaterThanOrEqualTo(0));

      final rooms = await repo.listRooms(query: query);
      expect(rooms, isNotEmpty);

      final intelligence = await repo.getTimetableIntelligence(
        query: query,
        academicYearId: 'year_1',
      );
      expect(intelligence.intelligenceScore, greaterThan(0));
    });
  });
}
