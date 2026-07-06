import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:flutter_test/flutter_test.dart';

MarksEntryProgress progress({
  int entered = 10,
  int total = 30,
  DateTime? deadline,
}) {
  return MarksEntryProgress(
    examId: 'exam_1',
    title: 'Unit Test',
    subject: 'Mathematics',
    grade: '8',
    sectionName: 'A',
    enteredCount: entered,
    totalCount: total,
    marksEntryDeadline: deadline,
  );
}

void main() {
  final asOf = DateTime.parse('2026-07-06T12:00:00Z');

  group('MarksEntryProgress.isOverdue (EXM-6)', () {
    test('past deadline with pending marks is overdue', () {
      final p = progress(deadline: DateTime.parse('2026-07-01T10:00:00Z'));
      expect(p.pending, 20);
      expect(p.isOverdue(asOf), isTrue);
    });

    test('past deadline but fully entered is NOT overdue', () {
      final p = progress(
        entered: 30,
        total: 30,
        deadline: DateTime.parse('2026-07-01T10:00:00Z'),
      );
      expect(p.pending, 0);
      expect(p.isOverdue(asOf), isFalse);
    });

    test('future deadline with pending marks is NOT overdue', () {
      final p = progress(deadline: DateTime.parse('2026-07-31T10:00:00Z'));
      expect(p.isOverdue(asOf), isFalse);
    });

    test('no deadline is never overdue', () {
      expect(progress(deadline: null).isOverdue(asOf), isFalse);
    });
  });
}
