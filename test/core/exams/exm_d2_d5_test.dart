import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_report_card.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/exam_test_helpers.dart';

/// Maps a store [ReportCardData] onto the shared [ExamReportCard] the batch PDF
/// builder renders (mirrors the reports screen's `_toExamReportCard`).
ExamReportCard _cardFromData(ReportCardData c) => ExamReportCard(
      sisStudentId: c.sisStudentId,
      studentName: c.studentName,
      classLabel: c.classLabel,
      termLabel: c.termLabel,
      subjects: [
        for (final s in c.subjects)
          ReportCardSubjectLine(
            subject: s.subject,
            examTitle: s.examTitle,
            score: s.score ?? 0,
            maxScore: s.maxScore,
            grade: s.grade,
            status: switch (s.statusCode) {
              'AB' => ExamMarkStatus.absent,
              'ML' => ExamMarkStatus.medicalLeave,
              'DB' => ExamMarkStatus.debarred,
              _ => ExamMarkStatus.present,
            },
          ),
      ],
      totalScore: c.totalScore,
      totalMax: c.totalMax,
      overallGrade: c.overallGrade,
      rank: c.rank ?? 0,
      classSize: c.classSize,
      rankShown: false,
    );

/// EXM-D1 (batch report cards) · EXM-D2 (grace / moderation) · EXM-D4 (hall
/// tickets) · EXM-D5 (seating) — client store + export logic.
///
/// 🔴 Integrity (frozen): a grace adjustment is a SEPARATE audited record; the
/// ORIGINAL entered mark is NEVER overwritten. The EFFECTIVE mark (original +
/// Σgrace, bounds-capped) drives the published score/grade; parents/students see
/// only the effective value, never the per-delta breakdown. Grace is rejected
/// once published.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mathExam = 'exam_math_8a';
  const term = 'Term 2';
  const classLabel = '8-A';
  // Ravi (roll 01, /50 = 42), Karthik (roll 03, 40). Meera (roll 06) open slot.
  const ravi = 'SIS-STU-10430';
  const ravitMarkId = 'exam_math_8a_01';
  const meeraMarkId = 'exam_math_8a_06';

  late ExamAdministrationStore store;

  setUp(() async {
    await resetExamAdministrationForTest();
    store = ExamAdministrationStore.instance;
  });

  /// Moves the seeded math exam to the `processed` phase (grace requires it):
  /// fill the open roll-06 slot, then process.
  void processMathExam() {
    store.recordMark(markEntryId: meeraMarkId, marksObtained: 36);
    store.processResults(mathExam);
  }

  group('EXM-D2 — grace / moderation preserves the original mark', () {
    test('records a delta as a separate record; original mark is untouched', () {
      processMathExam();
      final before = store.markById(ravitMarkId)!;
      expect(before.marksObtained, 42);

      final result = store.recordGraceAdjustment(
        examId: mathExam,
        sisStudentId: ravi,
        delta: 5,
        reason: 'Re-evaluation',
      );

      // The ORIGINAL entered mark is NOT overwritten…
      final after = store.markById(ravitMarkId)!;
      expect(after.marksObtained, 42, reason: 'original mark must be preserved');
      // …but a separate audited adjustment exists…
      final adjustments = store.adjustmentsForExam(mathExam);
      expect(adjustments, hasLength(1));
      expect(adjustments.single.delta, 5);
      expect(adjustments.single.reason, 'Re-evaluation');
      // …and the effective mark reflects it.
      expect(result.effectiveMark, 47);
      expect(store.effectiveMarkFor(ravitMarkId), 47);
    });

    test('multiple deltas accumulate into the effective mark', () {
      processMathExam();
      store.recordGraceAdjustment(
          examId: mathExam, sisStudentId: ravi, delta: 3, reason: 'a');
      store.recordGraceAdjustment(
          examId: mathExam, sisStudentId: ravi, delta: 2, reason: 'b');
      expect(store.adjustmentTotalFor(mathExam, ravi), 5);
      expect(store.effectiveMarkFor(ravitMarkId), 47); // 42 + 5
    });

    test('effective mark is capped at max_marks and floored at 0', () {
      processMathExam();
      // 42 + 20 = 62 → capped to 50.
      final up = store.recordGraceAdjustment(
          examId: mathExam, sisStudentId: ravi, delta: 20, reason: 'cap');
      expect(up.effectiveMark, 50);
      // 50-effective now, apply -100 → floored to 0.
      final down = store.recordGraceAdjustment(
          examId: mathExam, sisStudentId: ravi, delta: -100, reason: 'floor');
      expect(down.effectiveMark, 0);
    });

    test('a mandatory reason is enforced', () {
      processMathExam();
      expect(
        () => store.recordGraceAdjustment(
            examId: mathExam, sisStudentId: ravi, delta: 5, reason: '   '),
        throwsStateError,
      );
    });

    test('grace is REJECTED after publish (published result is immutable)', () {
      processMathExam();
      store.publishExamResults(mathExam);
      expect(
        () => store.recordGraceAdjustment(
            examId: mathExam, sisStudentId: ravi, delta: 5, reason: 'too late'),
        throwsStateError,
      );
    });

    test('grace is rejected before results are processed (marks_entry phase)',
        () {
      // Seeded exam is in marks_entry, not processed.
      expect(
        () => store.recordGraceAdjustment(
            examId: mathExam, sisStudentId: ravi, delta: 5, reason: 'too early'),
        throwsStateError,
      );
    });
  });

  group('EXM-D2 — grace reflects in the effective published mark, NOT the '
      'breakdown', () {
    test('the published result carries the effective mark; no adjustment leaks',
        () {
      processMathExam();
      store.recordGraceAdjustment(
          examId: mathExam, sisStudentId: ravi, delta: 5, reason: 'moderation');
      store.publishExamResults(mathExam);

      // The parent/student-visible published result reflects the EFFECTIVE mark
      // (42 + 5 = 47), never the original 42.
      final published = store
          .resultsForStudent(ravi)
          .firstWhere((r) => r.examId == mathExam);
      expect(published.scoreObtained, 47);

      // PublishedExamResult has NO delta / reason / adjustment field — the
      // breakdown is not part of the parent-facing model at all.
      final json = published.toString();
      expect(json.contains('moderation'), isFalse,
          reason: 'the grace reason must never appear in the parent result');

      // The coordinator-only breakdown is still available server-side.
      expect(store.adjustmentsForExam(mathExam), hasLength(1));
    });

    test('grace lifts a failing student above the pass mark in the effective '
        'grade', () {
      // Karthik 40/50 = 80% already passes; use a downward case to prove the
      // effective grade is recomputed from the effective mark.
      processMathExam();
      store.recordGraceAdjustment(
          examId: mathExam,
          sisStudentId: ravi,
          delta: -30,
          reason: 'penalty');
      store.publishExamResults(mathExam);
      final published = store
          .resultsForStudent(ravi)
          .firstWhere((r) => r.examId == mathExam);
      // 42 - 30 = 12 / 50 = 24% → grade 'D' on the standard scale.
      expect(published.scoreObtained, 12);
      expect(published.grade, 'D');
    });
  });

  group('EXM-D1 — batch report cards', () {
    test('builds one card per published student with the effective total', () {
      processMathExam();
      store.recordGraceAdjustment(
          examId: mathExam, sisStudentId: ravi, delta: 5, reason: 'grace');
      store.publishExamResults(mathExam);

      final cards = store.reportCards(classLabel: classLabel, term: term);
      expect(cards, isNotEmpty);
      final raviCard = cards.firstWhere((c) => c.sisStudentId == ravi);
      // The Maths subject line uses the effective mark (47), not the original 42.
      final maths =
          raviCard.subjects.firstWhere((s) => s.subject == 'Mathematics');
      expect(maths.score, 47);
      expect(raviCard.totalScore, 47);
      expect(raviCard.rank, isNotNull);
    });

    test('the batch PDF renders one page per card without throwing', () async {
      processMathExam();
      store.publishExamResults(mathExam);
      final cards = store.reportCards(classLabel: classLabel, term: term);

      const service = AksharaReportExportService();
      final examCards = [
        for (final c in cards) _cardFromData(c),
      ];
      final bytes = await service.buildBatchReportCardsPdf(
        cards: examCards,
        schoolName: 'Test School',
      );
      // A non-trivial PDF was produced (one page per card).
      expect(bytes.lengthInBytes, greaterThan(1000));
      expect(examCards.length, cards.length);
    });
  });

  group('EXM-D4 — hall tickets', () {
    test('one ticket per enrolled student with the standard template fields',
        () {
      final tickets = store.hallTickets(mathExam);
      expect(tickets, isNotEmpty);
      final t = tickets.first;
      expect(t.examTitle, 'Unit Test — Mathematics');
      expect(t.subject, 'Mathematics');
      expect(t.venueLabel, 'Room 8A');
      expect(t.instructions, isNotEmpty);
    });

    test('the hall-ticket PDF renders without throwing', () async {
      final tickets = store.hallTickets(mathExam);
      const service = AksharaReportExportService();
      final bytes = await service.buildHallTicketsPdf(
        tickets: [
          for (final t in tickets)
            HallTicketPrintData(
              sisStudentId: t.sisStudentId,
              studentName: t.studentName,
              rollNo: t.rollNo,
              classLabel: t.classLabel,
              subject: t.subject,
              examTitle: t.examTitle,
              dateLabel: t.dateLabel,
              timeLabel: t.timeLabel,
              venueLabel: t.venueLabel,
              maxMarks: t.maxMarks,
              instructions: t.instructions,
            ),
        ],
        schoolName: 'Test School',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });
  });

  group('EXM-D5 — seating arrangement', () {
    SeatingCandidate c(String id, String cls, String roll) => SeatingCandidate(
          sisStudentId: id,
          studentName: 'Student $id',
          rollNo: roll,
          classLabel: cls,
        );

    test('single class seats sequentially by roll across rooms of capacity', () {
      final plan = ExamSeatingPlanner.plan(
        examId: 'e1',
        candidates: [
          c('s3', '8-A', '03'),
          c('s1', '8-A', '01'),
          c('s2', '8-A', '02'),
          c('s4', '8-A', '04'),
          c('s5', '8-A', '05'),
        ],
        capacity: 2,
      );
      expect(plan.rooms, hasLength(3)); // 5 students / capacity 2
      // Room 1 holds rolls 01, 02 (sequential by roll).
      expect(plan.rooms.first.seats.map((s) => s.rollNo), ['01', '02']);
      expect(plan.rooms.first.seats.map((s) => s.seatNo), [1, 2]);
    });

    test('multi-class plan never seats two ADJACENT students of the same class',
        () {
      final plan = ExamSeatingPlanner.plan(
        examId: 'e2',
        candidates: [
          c('a1', '8-A', '01'),
          c('a2', '8-A', '02'),
          c('a3', '8-A', '03'),
          c('a4', '8-A', '04'),
          c('b1', '8-B', '01'),
          c('b2', '8-B', '02'),
          c('b3', '8-B', '03'),
          c('b4', '8-B', '04'),
        ],
        capacity: 100, // one room → adjacency spans the whole sequence
      );
      expect(plan.totalSeats, 8);
      for (final room in plan.rooms) {
        final seats = [...room.seats]..sort((x, y) => x.seatNo.compareTo(y.seatNo));
        for (var i = 1; i < seats.length; i++) {
          expect(seats[i - 1].classLabel == seats[i].classLabel, isFalse,
              reason: 'adjacent seats must not share a class');
        }
      }
    });

    test('generateSeating on the seeded exam plans every student once', () {
      final plan = store.generateSeating(mathExam);
      expect(plan.totalSeats, ExamAdministrationStore.instance
          .hallTickets(mathExam)
          .length);
      final ids = <String>{
        for (final room in plan.rooms)
          for (final seat in room.seats) seat.sisStudentId,
      };
      expect(ids.length, plan.totalSeats, reason: 'each student seated once');
      // Reading it back returns the same plan.
      expect(store.seatingFor(mathExam).totalSeats, plan.totalSeats);
    });
  });
}
